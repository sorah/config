# frozen_string_literal: true

require_relative "../local_config_file"

# Schema is managed by psqldef; Rails' migration and schema tasks do not apply.
Rake::Task.tasks.each do |task|
  case task.name
  when /\Adb:schema:/, /\Adb:migrate(:|\z)/, /\Adb:test:/, 'db:rollback', 'db:create', 'db:drop', 'db:setup', 'db:prepare'
    task.clear
  end
end

module DatabaseTasks
  def self.database_config
    database = ::Rails.application.config_for(:database)
    if ENV.key?('DATABASE_URL')
      database = database.merge(
        ActiveRecord::DatabaseConfigurations::ConnectionUrlResolver.new(ENV['DATABASE_URL']).to_hash,
      )
    end
    database
  end

  # In development, dev and test schemas are maintained together.
  def self.target_configs
    if ENV['DATABASE_URL'] || ENV['SKIP_TEST_DATABASE'] || !Rails.env.development?
      [database_config]
    else
      [database_config, Rails.application.config_for(:database, env: 'test')]
    end
  end

  # Runs a command through script/pdsql, retrying OCC conflicts (OC000/OC001); DDL conflicts with
  # concurrent DDL and async index completion on the same cluster. With check: false, other
  # failures only warn, for statements that fail when their object already exists.
  def self.pdsql(*args, env: {}, retry_occ: false, check: true)
    cmd = [Rails.root.join('script', 'pdsql').to_s, '--', *args]
    p cmd
    retries = 0
    loop do
      output = +""
      IO.popen(env, cmd, err: [:child, :out]) do |io|
        io.each_line do |line|
          $stdout.write(line)
          output << line
        end
      end
      status = $?
      break output if status.success?

      oc_error = output[/\(OC00[01]\)/]
      if retry_occ && oc_error && retries < 15
        retries += 1
        interval = [0.1 * (2**retries), 20.0].min * (1 + rand * 0.5)
        $stdout.puts "pdsql failed with #{oc_error}, retrying in #{interval.round(1)}s (#{retries}/15)..."
        sleep(interval)
        next
      end

      raise "Command failed with exit status #{status.exitstatus}: #{cmd.first}" if check || oc_error

      warn "Ignoring failure (exit status #{status.exitstatus})"
      break output
    end
  end

  # One statement per psql invocation: DSQL runs one DDL per transaction, and an OCC retry must
  # not re-run a statement that already succeeded.
  def self.psql_each(statements, env:, check: true)
    statements.each do |stmt|
      pdsql('psql', '-v', 'ON_ERROR_STOP=1', '-c', stmt, env:, retry_occ: true, check:)
    end
  end

  def self.app_env(config)
    {
      'PGHOST' => config.fetch(:host),
      'PGUSER' => config.fetch(:username),
      'PGOPTIONS' => "--search_path=#{config.fetch(:schema_search_path, 'public')}",
    }
  end

  def self.admin_env(config)
    {'PGHOST' => config.fetch(:host), 'PGUSER' => 'admin'}
  end

  def self.psqldef(args, config: database_config)
    Tempfile.open('schema.sql') do |f|
      Dir[Rails.root.join('db', 'schema', '*.sql')].sort.each do |path|
        f.puts File.read(path)
      end
      f.flush
      pdsql(
        'psqldef',
        '--user', config.fetch(:username),
        '--host', config.fetch(:host),
        # DSQL allows one DDL statement per transaction.
        '--config-inline', 'disable_ddl_transaction: true',
        '--config-inline', JSON.generate({target_schema: config.fetch(:schema_search_path, 'public')}),
        # Grants only widen; narrowing one needs a manual REVOKE via BEFORE_APPLY_SQL.
        '--config-inline', JSON.generate({manage: {privilege: [{target: 'app_admin'}, {target: 'app_user'}]}}),
        '--file', f.path,
        *args,
        'postgres',
        env: app_env(config),
        retry_occ: true
      )
    end
  end

  def self.pick_least_populated(candidates)
    counts = {}
    candidates.each do |host|
      count = yield(host)
      counts[host] = count unless count.nil?
    rescue RuntimeError => e
      warn "Skipping #{host}: #{e.message}"
    end
    return if counts.empty?

    puts "host\tschemata"
    counts.each { |host, count| puts "#{host}\t#{count}" }
    counts.keys.shuffle.min_by { |host| counts[host] }
  end

  # Turns the caller's assumed-role session ARN into the IAM role ARN that AWS IAM GRANT expects.
  def self.caller_role_arn
    caller_arn = Aws::STS::Client.new.get_caller_identity.arn
    assumed_role_arn = caller_arn.match(%r{arn:(?<partition>[^:]+):sts::(?<account_id>\d+):assumed-role/(?<role_name>[^/]+)/}) or
      abort "Expected assumed-role credentials (e.g. IAM Identity Center), got #{caller_arn}"
    role_name = assumed_role_arn[:role_name]
    path_prefix = if role_name.start_with?('AWSReservedSSO_')
      # IAM Identity Center roles live under a path naming the Identity Center home region.
      "aws-reserved/sso.amazonaws.com/#{ENV.fetch("AWS_SSO_REGION") { ENV.fetch("AWS_REGION") }}/"
    else
      ''
    end
    role_arn = "arn:#{assumed_role_arn[:partition]}:iam::#{assumed_role_arn[:account_id]}:role/#{path_prefix}#{role_name}"
    p role_arn
  end

  # DSQL caches catalog snapshots per connection; reusing one (even after reconnect!) never sees
  # a job finish or indisvalid flip to true. Each poll opens a fresh connection with a fresh token.
  def self.with_fresh_connection(config)
    password = DsqlAuthTokenGenerator.new.call(host: config.fetch(:host), port: 5432, user: config.fetch(:username))
    pg = PG.connect(
      host: config.fetch(:host),
      user: config.fetch(:username),
      password:,
      dbname: "postgres",
      sslmode: "verify-full",
      sslrootcert: DsqlHostResolver.ssl_root_cert,
    )
    begin
      yield pg
    ensure
      pg.close
    end
  end

  # Polls until the block returns no pending items; each is described in progress output.
  def self.wait_until_empty(what, timeout: 200, interval: 2)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
    loop do
      pending = yield
      break if pending.empty?

      remaining = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
      abort "Timed out waiting for #{what}: #{pending.join(", ")}" if remaining <= 0

      puts "Waiting for #{pending.size} #{what}: #{pending.join(", ")} (#{remaining.round}s remaining)"
      sleep interval
    end
  end

  # 120s was too tight for CI schema preparation.
  def self.wait_for_jobs(config)
    wait_until_empty("DSQL async job(s)") do
      with_fresh_connection(config) do |pg|
        pg.exec("SELECT job_id, status FROM sys.jobs WHERE status NOT IN ('completed', 'failed')")
          .map { |j| "#{j["job_id"]} (#{j["status"]})" }
      end
    end
  end

  def self.wait_for_indexes(config)
    sql = <<~SQL
      SELECT c.relname AS index_name
      FROM pg_index i
      JOIN pg_class c ON c.oid = i.indexrelid
      JOIN pg_class t ON t.oid = i.indrelid
      JOIN pg_namespace n ON n.oid = t.relnamespace
      WHERE n.nspname = $1
        AND i.indisunique = true
        AND i.indisvalid = false
    SQL
    wait_until_empty("unique index(es) to become valid") do
      with_fresh_connection(config) do |pg|
        pg.exec_params(sql, [config.fetch(:schema_search_path, "public")]).map { |r| r["index_name"] }
      end
    end
  end
end

namespace :db do
  task :validate_user do # rubocop:disable Rails/RakeEnvironment
    require_relative "../dsql_host_resolver"
    DsqlHostResolver.validate_dsql_user!
  end

  desc "Pin the least-populated dev/test DSQL cluster into tmp/ (FORCE=1 to re-pick)"
  task :pick_cluster do # rubocop:disable Rails/RakeEnvironment
    require_relative "../dsql_host_resolver"

    pairs = [
      [
        DsqlHostResolver.method(:dev_srv_candidates),
        DsqlHostResolver::DEV_CACHE_PATH,
        DsqlHostResolver::DEV_SRV_NAME,
        DsqlHostResolver::DEV_DNS_NAME,
        "DSQL_DEV_HOST",
      ],
    ]
    unless ENV['SKIP_TEST_DATABASE']
      pairs << [
        DsqlHostResolver.method(:test_srv_candidates),
        DsqlHostResolver::TEST_CACHE_PATH,
        DsqlHostResolver::TEST_SRV_NAME,
        DsqlHostResolver::TEST_DNS_NAME,
        "DSQL_TEST_HOST",
      ]
    end

    pairs.each do |resolve_candidates, cache_path, srv_name, dns_name, env_key|
      if ENV[env_key].to_s != ""
        puts "#{env_key} is set; skipping"
        next
      end

      if (existing = LocalConfigFile.find(cache_path)) && ENV['FORCE'] != '1'
        puts "#{existing} exists (#{File.read(existing).strip}); skipping"
        next
      end

      candidates = resolve_candidates.call
      if candidates.empty?
        warn "No SRV records found for #{srv_name}; falling back to #{dns_name} on first connect"
        next
      end

      chosen = DatabaseTasks.pick_least_populated(candidates) do |host|
        out = DatabaseTasks.pdsql(
          'psql', '-tA', '-c',
          "SELECT (SELECT count(*) FROM information_schema.schemata), " \
            "(SELECT count(*) FROM pg_roles WHERE rolname = 'developer')",
          env: {'PGUSER' => 'admin', 'PGHOST' => host},
          retry_occ: true
        )
        schemata, developer_role = out.lines.map(&:strip).reject(&:empty?).last.to_s.split("|").map(&:to_i)
        if developer_role == 1
          schemata
        else
          warn "Skipping #{host}: not bootstrapped (run rake db:init against it)"
          nil
        end
      end
      abort "Could not reach any candidate cluster for #{srv_name}" if chosen.nil?

      cache_file = LocalConfigFile.write_path(cache_path)
      FileUtils.mkdir_p(File.dirname(cache_file))
      File.write(cache_file, chosen)
      puts "Selected #{chosen} -> #{cache_file}"
    end
  end

  desc "Bootstrap dev/test clusters: permission roles and the developer role mapped to your IAM role"
  task init: [:load_config, :validate_user] do
    role_arn = DatabaseTasks.caller_role_arn
    DatabaseTasks.target_configs.each do |config|
      puts "Creating developer role on #{config.fetch(:host)} for #{role_arn}"
      # check: false, since roles that already exist make CREATE ROLE fail on a re-run.
      DatabaseTasks.psql_each(
        [
          "CREATE ROLE app_admin;",
          "CREATE ROLE app_user;",
          "GRANT app_user TO app_admin;",
          "CREATE ROLE developer WITH LOGIN;",
          "AWS IAM GRANT developer TO '#{role_arn}';",
          "GRANT app_admin TO developer;",
          "GRANT developer TO admin;",
        ],
        env: DatabaseTasks.admin_env(config),
        check: false,
      )
    end
  end

  desc "Create your personal schema and login role on the dev and test clusters"
  task create: [:load_config, :validate_user] do
    role_arn = DatabaseTasks.caller_role_arn
    DatabaseTasks.target_configs.each do |config|
      username = config.fetch(:username)
      schema = config.fetch(:schema_search_path)
      puts "Creating schema #{schema} on #{config.fetch(:host)}"
      DatabaseTasks.psql_each(
        [
          "CREATE ROLE #{username} WITH LOGIN;",
          "GRANT developer TO #{username};",
          "ALTER ROLE #{username} SET search_path TO #{schema};",
          "AWS IAM GRANT #{username} TO '#{role_arn}';",
        ],
        env: DatabaseTasks.admin_env(config),
        check: false,
      )
      DatabaseTasks.psql_each(
        ["CREATE SCHEMA IF NOT EXISTS #{schema} AUTHORIZATION developer;"],
        env: DatabaseTasks.admin_env(config),
      )
    end
  end

  desc "Apply db/schema/*.sql with psqldef (BEFORE_APPLY_SQL runs first, ENABLE_DROP=1 allows drops)"
  task migrate: [:environment, :validate_user] do
    DatabaseTasks.target_configs.each do |config|
      if ENV['BEFORE_APPLY_SQL'].to_s != ''
        puts "Running before-apply SQL: #{ENV["BEFORE_APPLY_SQL"]}"
        # Split naively on ';', so statements must not contain one in a literal.
        stmts = ENV['BEFORE_APPLY_SQL'].split(';').map(&:strip).reject(&:empty?).map { "#{_1};" }
        DatabaseTasks.psql_each(stmts, env: DatabaseTasks.app_env(config))
        DatabaseTasks.wait_for_jobs(config)
      end
      args = []
      args << '--enable-drop' if ENV['ENABLE_DROP'] == '1'
      DatabaseTasks.psqldef(args, config:)
    end
  end

  desc "Show the psqldef plan without applying it"
  task 'migrate:status' => [:environment, :validate_user] do
    DatabaseTasks.psqldef(['--dry-run'])
  end

  desc "Drop your personal schema (the login role stays; db:prune_ci shows how to remove one)"
  task drop: [:load_config, :validate_user] do
    DatabaseTasks.target_configs.each do |config|
      schema = config.fetch(:schema_search_path)
      puts "Dropping schema #{schema} on #{config.fetch(:host)}"
      DatabaseTasks.psql_each(["DROP SCHEMA IF EXISTS #{schema} CASCADE;"], env: DatabaseTasks.admin_env(config))
    end
  end

  desc "Create your schema and role (if needed) and apply db/schema"
  task setup: ['db:create', 'db:migrate']

  # db:create provisions per-developer schemas, so deployed environments only migrate.
  desc "Apply db/schema, creating your schema and role first in development and test"
  task prepare: :load_config do
    Rake::Task['db:create'].invoke if Rails.env.local?
    Rake::Task['db:migrate'].invoke
  end

  desc "Measure simple SELECT query latency (SELECT NOW())"
  task measure_latency: :environment do
    iterations = (ENV["LATENCY_ITERATIONS"] || 10).to_i
    latencies = []

    db_host = DatabaseTasks.database_config.fetch(:host)
    puts "Host: #{db_host}"

    ActiveRecord::Base.with_connection do |connection|
      puts "Running warmup query to establish connection..."
      connection.execute("SELECT NOW()")

      puts "Measuring SELECT NOW() latency (#{iterations} iterations)..."

      iterations.times do |i|
        start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        connection.execute("SELECT NOW()")
        end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        latency_ms = (end_time - start_time) * 1000
        latencies << latency_ms
        puts "  Iteration #{i + 1}: #{latency_ms.round(2)} ms"
      end
    end

    min_latency = latencies.min
    max_latency = latencies.max
    avg_latency = latencies.sum / latencies.size
    sorted = latencies.sort
    p50_latency = sorted[(latencies.size * 0.5).ceil - 1]
    p90_latency = sorted[(latencies.size * 0.9).ceil - 1]
    p99_latency = sorted[(latencies.size * 0.99).ceil - 1]

    puts "\nLatency Statistics:"
    puts "  Min: #{min_latency.round(2)} ms"
    puts "  Max: #{max_latency.round(2)} ms"
    puts "  Avg: #{avg_latency.round(2)} ms"
    puts "  P50: #{p50_latency.round(2)} ms"
    puts "  P90: #{p90_latency.round(2)} ms"
    puts "  P99: #{p99_latency.round(2)} ms"

    # GitHub-hosted runners run on Azure; this CNAME reveals the runner's Azure region.
    dig_cname = IO.popen(%w[dig azure.archive.ubuntu.com], "r", &:read).each_line.grep(/CNAME/).join.strip

    if ENV["GITHUB_ENV"]
      File.open(ENV.fetch("GITHUB_ENV"), "a") do |f|
        f.puts "DSQL_AVG_LATENCY_MS=#{avg_latency.round(4)}"
      end
      puts "\nDSQL_AVG_LATENCY_MS=#{avg_latency.round(4)} written to GITHUB_ENV"
      puts dig_cname
    end

    if ENV["GITHUB_STEP_SUMMARY"]
      File.open(ENV.fetch("GITHUB_STEP_SUMMARY"), "a") do |f|
        f.puts "## Database Query Latency (SELECT NOW())"
        f.puts ""
        f.puts "- Host: `#{db_host}`"
        f.puts "- Latency (#{iterations} iterations): min #{min_latency.round(2)}ms / avg #{avg_latency.round(2)}ms / p50 #{p50_latency.round(2)}ms / p90 #{p90_latency.round(2)}ms / p99 #{p99_latency.round(2)}ms / max #{max_latency.round(2)}ms"
        f.puts "- `dig azure.archive.ubuntu.com` CNAME: ```#{dig_cname}```"
        f.puts ""
      end
      puts "\nResults written to GITHUB_STEP_SUMMARY"
    end
  end

  desc "Prune old CI/agent database schemas and users (PREFIX, THRESHOLD required; set DSQL_DEV_HOST and DSQL_CLUSTER_USER=admin)"
  task prune_ci: :environment do
    prefix = ENV.fetch("PREFIX")
    threshold = ENV.fetch("THRESHOLD").to_i
    dry_run = ENV.key?("DRY_RUN")
    cutoff = Time.now.utc - threshold

    pattern = /\A#{Regexp.escape(prefix)}_(\d{8})_[a-zA-Z0-9_]+\z/

    ActiveRecord::Base.with_connection do |connection|
      schemata = connection.select_values("SELECT schema_name FROM information_schema.schemata")
        .select { |s| s.match?(pattern) }

      roles = connection.select_values("SELECT rolname FROM pg_roles")
        .select { |r| r.match?(pattern) }

      puts "Found #{schemata.size} matching schemata: #{schemata.join(", ")}"
      puts "Found #{roles.size} matching roles: #{roles.join(", ")}"

      expired = ->(name) {
        date_str = name.match(pattern)[1]
        begin
          Time.utc(date_str[0, 4].to_i, date_str[4, 2].to_i, date_str[6, 2].to_i) < cutoff
        rescue ArgumentError
          false
        end
      }

      old_schemata = schemata.select(&expired)
      old_roles = roles.select(&expired)

      puts "Pruning #{old_schemata.size} schemata, #{old_roles.size} roles (cutoff: #{cutoff})"

      old_schemata.each do |schema_name|
        quoted = connection.quote_column_name(schema_name)
        if dry_run
          puts "[dry-run] Would drop schema #{quoted}"
        else
          puts "Dropping schema #{quoted}"
          retries = 0
          begin
            connection.execute("DROP SCHEMA IF EXISTS #{quoted} CASCADE")
          rescue ActiveRecord::SerializationFailure
            retries += 1
            raise if retries > 15

            sleep 0.1 * retries
            retry
          end
        end
      end

      old_roles.each do |role_name|
        quoted = connection.quote_column_name(role_name)
        if dry_run
          puts "[dry-run] Would drop role #{quoted}"
        else
          puts "Dropping role #{quoted}"
          retries = 0
          begin
            # A role with IAM mappings or memberships cannot be dropped.
            iam_arns = connection.select_values(
              "SELECT arn FROM sys.iam_pg_role_mappings WHERE pg_role_name = #{connection.quote(role_name)}",
            )
            iam_arns.each do |arn|
              puts "  Revoking IAM grant for #{arn}"
              connection.execute("AWS IAM REVOKE #{quoted} FROM #{connection.quote(arn)}")
            end

            granted_roles = connection.select_values(
              "SELECT rolname FROM pg_roles WHERE oid IN " \
                "(SELECT roleid FROM pg_auth_members WHERE member = (SELECT oid FROM pg_roles WHERE rolname = #{connection.quote(role_name)}))",
            )
            granted_roles.each do |granted_role|
              puts "  Revoking role #{granted_role}"
              connection.execute("REVOKE #{connection.quote_column_name(granted_role)} FROM #{quoted}")
            end

            connection.execute("DROP ROLE IF EXISTS #{quoted}")
          rescue ActiveRecord::SerializationFailure
            retries += 1
            raise if retries > 15

            sleep 0.1 * retries
            retry
          end
        end
      end
    end

    puts "Done"
  end

  desc "Wait for DSQL async jobs (e.g. index builds and drops) to complete"
  task wait_for_jobs: :environment do
    DatabaseTasks.target_configs.each { DatabaseTasks.wait_for_jobs(_1) }
  end

  desc "Wait for DSQL async unique indexes to become valid"
  task wait_for_indexes: :environment do
    DatabaseTasks.target_configs.each { DatabaseTasks.wait_for_indexes(_1) }
  end

  desc "Create tmp/dsql-user.txt and tmp/dsql-schema.txt for an isolated agent session"
  task :agent_user do # rubocop:disable Rails/RakeEnvironment
    session_id = ENV['SESSION_ID']
    if session_id.nil? || session_id.empty? # rubocop:disable Rails/Blank
      abort "Error: SESSION_ID is required.\n" \
        "Usage: rails db:agent_user SESSION_ID=xxx"
    end

    user_file = LocalConfigFile.write_path("tmp/dsql-user.txt")
    schema_file = LocalConfigFile.write_path("tmp/dsql-schema.txt")
    # The date lets db:prune_ci (PREFIX=agent) expire it.
    name = "agent_#{Time.now.utc.strftime("%Y%m%d")}_#{session_id.gsub(/[^a-zA-Z0-9_]/, "")}"

    FileUtils.mkdir_p(File.dirname(user_file))
    File.write(user_file, name)
    File.write(schema_file, name)

    puts "Created #{user_file} with username: #{name}"
    puts "Created #{schema_file} with schema prefix: #{name}"
  end
end
