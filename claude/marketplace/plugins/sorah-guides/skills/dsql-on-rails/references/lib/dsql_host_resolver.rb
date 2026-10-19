# frozen_string_literal: true

require "fileutils"
require "resolv"

require_relative "local_config_file"

# Resolves the DSQL cluster, login role and schema for development and test.
# Precedence: env override, then the pin file under tmp/, then the CNAME (whose answer is pinned).
module DsqlHostResolver
  # Replace with your own names. The CNAME points at a default cluster; the SRV rrset lists all of them.
  DEV_DNS_NAME = "dev-dsql.example.com"
  TEST_DNS_NAME = "test-dsql.example.com"
  DEV_SRV_NAME = "_postgresql._tcp.#{DEV_DNS_NAME}"
  TEST_SRV_NAME = "_postgresql._tcp.#{TEST_DNS_NAME}"
  DEV_CACHE_PATH = "tmp/dev-dsql-cluster.txt"
  TEST_CACHE_PATH = "tmp/test-dsql-cluster.txt"

  # Usernames shared by every sandbox of a kind would make sessions collide on one schema.
  SHARED_USERNAMES = %w[ubuntu root].freeze

  class << self
    def resolve(dns_name, cache_read: nil, cache_write: nil, env_override: nil)
      if env_override
        env_value = ENV[env_override]
        if env_value.present?
          return use_or_resolve(env_value, cache_file: cache_write)
        end
      end

      if cache_read
        return use_or_resolve(cache_read, cache_file: nil)
      end

      host = resolve_cname(dns_name)

      if cache_write
        FileUtils.mkdir_p(File.dirname(cache_write))
        File.write(cache_write, host)
      end

      host
    end

    def dev_cache_file
      LocalConfigFile.write_path(DEV_CACHE_PATH)
    end

    def test_cache_file
      LocalConfigFile.write_path(TEST_CACHE_PATH)
    end

    def dev_host
      resolve(
        DEV_DNS_NAME,
        cache_read: LocalConfigFile.read(DEV_CACHE_PATH),
        cache_write: dev_cache_file,
        env_override: "DSQL_DEV_HOST",
      )
    end

    def test_host
      resolve(
        TEST_DNS_NAME,
        cache_read: LocalConfigFile.read(TEST_CACHE_PATH),
        cache_write: test_cache_file,
        env_override: "DSQL_TEST_HOST",
      )
    end

    def resolve_srv(name)
      Resolv::DNS.open do |dns|
        dns.getresources(name, Resolv::DNS::Resource::IN::SRV).map do |record|
          {priority: record.priority, weight: record.weight, target: record.target.to_s.delete_suffix(".")}
        end
      end
    end

    def srv_candidates(name)
      resolve_srv(name)
        .sort_by { [_1[:priority], _1[:target]] }
        .map { _1[:target] }
        .uniq
    end

    def dev_srv_candidates
      srv_candidates(DEV_SRV_NAME)
    end

    def test_srv_candidates
      srv_candidates(TEST_SRV_NAME)
    end

    def dsql_user
      if ENV.key?("DSQL_CLUSTER_USER")
        ENV.fetch("DSQL_CLUSTER_USER")
      elsif (user = LocalConfigFile.read("tmp/dsql-user.txt"))
        user
      else
        ENV.fetch("USER", "unknownuser").gsub(/[^a-zA-Z0-9_]/, "")
      end
    end

    def validate_dsql_user!
      user = dsql_user
      if SHARED_USERNAMES.include?(user)
        raise "DSQL username cannot be #{user.inspect}. Set DSQL_CLUSTER_USER or create tmp/dsql-user.txt " \
          "(an isolated agent session can run `rails db:agent_user SESSION_ID=xxx`)."
      end
      user
    end

    # AmazonRootCA1 for verifying DSQL TLS: the container image copy, then the in-repo copy,
    # then libpq's system trust store.
    def ssl_root_cert
      @ssl_root_cert ||= [
        "/etc/amazonroot.pem",
        File.expand_path("../data/amazonroot.pem", __dir__),
      ].find { |p| File.exist?(p) } || "system"
    end

    def dsql_schema(env_key:, default_suffix:)
      return ENV.fetch(env_key) if ENV.key?(env_key)

      if (schema = LocalConfigFile.read("tmp/dsql-schema.txt"))
        "#{schema}#{default_suffix}"
      else
        "#{ENV.fetch("USER", "unknownuser").gsub(/[^a-zA-Z0-9_]/, "")}#{default_suffix}"
      end
    end

    # Accepts a cluster endpoint as is, or a DNS name to resolve through its CNAME.
    private def use_or_resolve(value, cache_file: nil)
      if value.end_with?(".aws")
        value
      else
        host = resolve_cname(value)
        if cache_file
          FileUtils.mkdir_p(File.dirname(cache_file))
          File.write(cache_file, host)
        end
        host
      end
    end

    private def resolve_cname(dns_name)
      Resolv::DNS.open do |dns|
        dns.getresource(dns_name, Resolv::DNS::Resource::IN::CNAME).name.to_s
      end
    end
  end
end
