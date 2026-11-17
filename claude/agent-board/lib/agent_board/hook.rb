# frozen_string_literal: true

require 'open3'

module AgentBoard
  # Entry point for every Claude Code hook event. Must stay fast and never touch the network.
  class Hook
    CONTEXT_EVENTS = %w[SessionStart UserPromptSubmit PostToolUse].freeze

    # I/O the state machine needs, kept out of State so it stays testable.
    class Lookup
      def initialize(store:)
        @store = store
      end

      def commit_subject(cwd)
        Git.output(cwd, 'log', '-1', '--format=%s')
      end

      def team_keys
        @team_keys ||= begin
          env = ENV['SORAH_AGENT_BOARD_LINEAR_TEAMS'].to_s.split(',').map(&:strip)
          file = @store.path('cache', 'linear-teams.json')
          (env + (File.exist?(file) ? JSON.parse(File.read(file)) : [])).uniq
        end
      end
    end

    module Git
      def self.output(cwd, *args)
        return if cwd.nil?

        out, status = Open3.capture2('git', '-C', cwd, *args, err: File::NULL)
        status.success? ? out.strip : nil
      rescue Errno::ENOENT
        nil
      end

      def self.branch(cwd) = output(cwd, 'symbolic-ref', '--short', '-q', 'HEAD')

      def self.repo(cwd)
        url = output(cwd, 'remote', 'get-url', 'origin')
        url&.[](%r{github\.com[:/]([\w.-]+/[\w.-]+?)(?:\.git)?\z}, 1)
      end
    end

    def initialize(store:, env: ENV, now: Time.now)
      @store = store
      @env = env
      @now = now
      @lookup = Lookup.new(store:)
    end

    # Returns the JSON string to print on stdout, or nil.
    def call(input)
      payload = JSON.parse(input)
      dump(payload) if @env['SORAH_AGENT_BOARD_DEBUG'] == '1'
      id = payload['session_id']
      return if id.nil?

      event = payload.fetch('hook_event_name')
      park_pane_predecessors(id) if event == 'SessionStart'

      context = nil
      session = @store.update(id, now: @now) do |s|
        events = State.new(lookup: @lookup).apply(s, payload, now: @now)
        events.concat(enrich(s, payload)) if %w[SessionStart PostToolUse].include?(event)
        context = context_for(s, event)
        events
      end
      write_env_file(session) if event == 'SessionStart'
      if event == 'UserPromptSubmit' && session.name != Snapshot::CHIEF_NAME && !File.exist?(@store.relay_marker(id))
        @store.record_user_activity(@now)
      end
      return unless context && CONTEXT_EVENTS.include?(event)

      JSON.generate('hookSpecificOutput' => {'hookEventName' => event, 'additionalContext' => context})
    end

    # Facts that need git or tmux; refreshed at start and after commands that may switch branches.
    private def enrich(session, payload)
      events = []
      if payload['hook_event_name'] == 'SessionStart'
        session.tmux_socket = Tmux.socket_from_env(@env)
        session.tmux_pane = @env['TMUX_PANE']
        session.lane = Tmux.lane(session.tmux_socket, session.tmux_pane)
        session.name ||= @env['SORAH_AGENT_BOARD_NAME'] || session.lane&.split(':', 2)&.last
        session.repo = Git.repo(session.cwd)
        events.concat(apply_dispatch(session))
      elsif !(payload['tool_name'] == 'Bash' && payload.dig('tool_input', 'command').to_s.match?(/\bgit\s+(switch|checkout)\b/))
        return events
      end

      session.branch = Git.branch(session.cwd)
      if session.issue.nil? && (ref = IssueRef.from_branch(session.branch, repo: session.repo, team_keys: @lookup.team_keys))
        session.issue = ref.merge('source' => 'branch', 'at' => @now.iso8601)
        events << {'at' => @now.iso8601, 'kind' => 'link', 'text' => "Linked to #{ref.fetch('key')} (branch)"}
      end
      events
    end

    # The chief of staff launches agents with SORAH_AGENT_BOARD_DISPATCH pointing at a brief it wrote.
    private def apply_dispatch(session)
      id = @env['SORAH_AGENT_BOARD_DISPATCH']
      return [] if id.nil? || !id.match?(/\A[\w-]+\z/)

      file = @store.path('pending', "#{id}.json")
      return [] unless File.exist?(file)

      brief = JSON.parse(File.read(file))
      session.name = brief['name'] if brief['name']
      session.goal = brief['goal'] if brief['goal']
      if (ref = brief['issue'] && IssueRef.parse_explicit(brief['issue']))
        session.issue = ref.merge('source' => 'dispatch', 'at' => @now.iso8601)
      end
      File.delete(file)
      [{'at' => @now.iso8601, 'kind' => 'dispatch', 'text' => "Dispatched: #{session.goal}"}]
    end

    # A new session in a pane replaces whatever ran there before (/clear, a restarted claude).
    private def park_pane_predecessors(id)
      socket = Tmux.socket_from_env(@env)
      pane = @env['TMUX_PANE']
      return if socket.nil? || pane.nil?

      @store.sessions.each do |other|
        next if other.id == id || other.parked_at || other.tmux_socket != socket || other.tmux_pane != pane

        @store.update(other.id, now: @now) do |s|
          s.parked_at = @now.iso8601
          s.turn_active = false
          s.blockers = []
          [{'at' => @now.iso8601, 'kind' => 'parked', 'text' => 'Replaced by a new session in the same pane'}]
        end
      end
    end

    private def context_for(session, event)
      parts = []
      parts << File.read(File.join(ROOT, 'agent-protocol.md')).strip if event == 'SessionStart'
      if session.issue && session.issue_announced != session.issue['key']
        session.issue_announced = session.issue['key']
        parts << issue_context(session.issue)
      elsif session.issue.nil? && event == 'UserPromptSubmit' && session.issue_announced.nil?
        session.issue_announced = 'untracked'
        parts << 'Agent board: this session is not linked to a Linear or GitHub issue yet. ' \
                 'When you identify the issue this work belongs to, run `sorah-agent-board link KEY_OR_URL`. ' \
                 'Do not create, comment on or modify issues unless the user explicitly asks.'
      end
      parts.empty? ? nil : parts.join("\n\n")
    end

    private def issue_context(issue)
      cached = @store.path('cache', 'issues', "#{issue['key'].tr('/#', '__')}.json")
      brief = File.exist?(cached) ? JSON.parse(File.read(cached)) : {}
      title = brief['title']
      read = issue['tracker'] == 'linear' ? 'the Linear MCP tools' : '`gh issue view`'
      ["Agent board: this work is tracked as #{issue['key']}#{" (#{title})" if title}#{" #{issue['url']}" if issue['url']}.",
       ("Brief from the chief of staff: #{brief['summary'].to_s.slice(0, 600)}" if brief['summary']),
       "Read it with #{read} before starting, keep the work within its scope, and name new branches after it.",
       'Do not comment on or change the issue unless the user explicitly asks.'].compact.join(' ')
    end

    private def write_env_file(session)
      file = @env['CLAUDE_ENV_FILE']
      return if file.nil?

      File.open(file, 'a') { it.puts("export SORAH_AGENT_BOARD_SESSION=#{session.id}") }
    end

    private def dump(payload)
      dir = @store.path('debug')
      FileUtils.mkdir_p(dir)
      File.write(File.join(dir, "#{@now.strftime('%Y%m%dT%H%M%S%N')}-#{payload['hook_event_name']}.json"),
                 JSON.pretty_generate(payload))
    end
  end
end
