# frozen_string_literal: true

require 'digest'
require 'open3'
require 'timeout'

module AgentBoard
  # PR facts for a session's branch via `gh`, cached on disk so viewers can refresh often.
  class PullRequests
    FIELDS = 'number,url,state,isDraft,reviewDecision,statusCheckRollup'
    TTL = {live: 120, parked: 3600}.freeze
    GH_TIMEOUT = 10

    def initialize(store:, now: Time.now)
      @store = store
      @now = now
      FileUtils.mkdir_p(@store.path('cache', 'pr'))
    end

    def for_sessions(sessions)
      targets = sessions.select { it.cwd && (it.branch || it.pr_url) }
      threads = targets.to_h { |s| [s.id, Thread.new { fetch(s) }] }
      threads.transform_values(&:value)
    end

    private def fetch(session)
      ref = session.pr_url || session.branch
      cache = @store.path('cache', 'pr', "#{Digest::SHA256.hexdigest("#{session.cwd}\0#{ref}")}.json")
      ttl = session.parked_at ? TTL.fetch(:parked) : TTL.fetch(:live)
      return JSON.parse(File.read(cache)) if File.exist?(cache) && @now - File.mtime(cache) < ttl

      result = query(session.cwd, ref)
      @store.write_atomically(cache, JSON.generate(result))
      result
    end

    # Returns nil (cached as null) when the branch has no PR.
    private def query(cwd, ref)
      Open3.popen2('gh', 'pr', 'view', ref, '--json', FIELDS, chdir: cwd, err: File::NULL) do |stdin, stdout, wait|
        stdin.close
        out = Timeout.timeout(GH_TIMEOUT) { stdout.read }
        return unless wait.value.success?

        summarize(JSON.parse(out))
      rescue Timeout::Error
        Process.kill(:TERM, wait.pid)
        nil
      end
    rescue Errno::ENOENT
      nil
    end

    private def summarize(pr)
      checks = pr.fetch('statusCheckRollup', []).map { it['conclusion'] || it['state'] || it['status'] }
      {
        'number' => pr.fetch('number'),
        'url' => pr.fetch('url'),
        'repo' => pr.fetch('url')[%r{github\.com/([^/]+/[^/]+)/pull}, 1],
        'state' => pr.fetch('state'),
        'draft' => pr.fetch('isDraft'),
        'review' => pr['reviewDecision'],
        'ci' => {
          'passed' => checks.count { %w[SUCCESS NEUTRAL SKIPPED].include?(it) },
          'failed' => checks.count { %w[FAILURE ERROR CANCELLED TIMED_OUT ACTION_REQUIRED STARTUP_FAILURE].include?(it) },
          'pending' => checks.count { %w[PENDING QUEUED IN_PROGRESS EXPECTED WAITING].include?(it) },
        },
      }
    end
  end
end
