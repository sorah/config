# frozen_string_literal: true

require 'digest'

module AgentBoard
  # Applies one hook payload to a Session and returns the timeline events it produced.
  class State
    QUESTION_TOOLS = {'AskUserQuestion' => 'question', 'ExitPlanMode' => 'plan'}.freeze
    EDIT_TOOLS = %w[Write Edit MultiEdit NotebookEdit].freeze
    TEST_COMMAND = /\b(rspec|rake|cargo (?:test|build|clippy)|bun (?:test|run (?:test|typecheck))|npm test|pnpm test|go test|pytest|just (?:test|check)|hk check|make|tsc)\b/
    MAX_EDITED_FILES = 200

    # lookup answers questions that need I/O: #commit_subject(cwd), #team_keys.
    def initialize(lookup:)
      @lookup = lookup
    end

    attr_reader :lookup

    def apply(session, payload, now:)
      @session = session
      @payload = payload
      @now = now
      @events = []
      before = session.status

      dispatch(payload.fetch('hook_event_name'))

      session.updated_at = now.iso8601
      session.status_since = now.iso8601 if session.status != before || session.status_since.nil?
      @events
    end

    attr_reader :session, :payload

    private def dispatch(event)
      case event
      when 'SessionStart' then session_start
      when 'UserPromptSubmit' then user_prompt_submit
      when 'PreToolUse' then pre_tool_use
      when 'PostToolUse' then post_tool_use(failed: false)
      when 'PostToolUseFailure' then post_tool_use(failed: true)
      when 'PermissionRequest' then permission_request
      when 'PermissionDenied' then clear_tool(payload['tool_use_id'])
      when 'Elicitation' then elicitation
      when 'ElicitationResult' then session.blockers.reject! { it['kind'] == 'mcp' }
      when 'SubagentStart' then session.turn_active = true
      when 'Notification' then notification
      when 'Stop' then stop
      when 'StopFailure' then stop_failure
      when 'SessionEnd' then session_end
      end
    end

    private def session_start
      session.transcript_path = payload['transcript_path']
      session.cwd = payload['cwd']
      session.parked_at = nil
      # Context injected earlier is gone after compact, clear and resume, so the issue is announced again.
      session.issue_announced = nil
      event('resumed', "Session #{payload['source']}") if %w[resume].include?(payload['source'])
      event('started', 'Session started') if payload['source'] == 'startup'
    end

    private def user_prompt_submit
      prompt = payload['prompt'].to_s
      first_prompt = session.goal.nil?
      session.goal ||= prompt.lines.first&.strip&.slice(0, 160)
      session.turn_active = true
      session.seen = true
      session.blockers = []
      session.ask = nil
      session.wait = nil
      session.error = nil
      event('prompt', prompt.strip.slice(0, 300))
      # Later turns carry pasted logs and harness-injected reports, so only the opening request names the work.
      link(IssueRef.from_text(prompt, team_keys: lookup.team_keys), source: 'prompt') if first_prompt
    end

    private def pre_tool_use
      session.turn_active = true
      tool = payload['tool_name']
      id = payload['tool_use_id']
      session.pending_tools[id] = tool_digest(tool, payload['tool_input']) if id
      kind = QUESTION_TOOLS[tool]
      add_blocker(kind, id, question_summary(tool)) if kind
    end

    private def post_tool_use(failed:)
      clear_tool(payload['tool_use_id'])
      # A subagent's commands describe its own sandboxed task, not this session's work.
      return if payload['agent_id']

      tool = payload['tool_name']
      input = payload['tool_input'] || {}
      case tool
      when *EDIT_TOOLS then record_edit(input['file_path'] || input['notebook_path'])
      when 'Bash' then bash_milestone(input['command'].to_s, failed:)
      when /get_issue\z/ then link(IssueRef.parse_explicit((input['id'] || input['issueId']).to_s), source: 'tool') unless failed
      end
    end

    private def permission_request
      tool = payload['tool_name']
      digest = tool_digest(tool, payload['tool_input'])
      id = session.pending_tools.key(digest)
      add_blocker('permission', id, "#{tool}: #{tool_target(payload['tool_input'])}")
    end

    private def elicitation
      add_blocker('mcp', nil, "#{payload['mcp_server_name'] || 'MCP'}: #{payload['message']}".strip)
    end

    private def notification
      case payload['notification_type']
      when 'idle_prompt'
        # The prompt box is showing, so no turn or dialog is in progress (e.g. after Esc).
        session.turn_active = false
        session.blockers = []
      when 'permission_prompt'
        add_blocker('permission', nil, payload['message'].to_s) if session.blockers.none?
      end
    end

    private def stop
      session.turn_active = false
      session.seen = false
      session.blockers = []
      session.pending_tools = {}
      text = payload['last_assistant_message'].to_s.strip
      return if text.empty?

      session.last_report = {'text' => text, 'at' => @now.iso8601, 'source' => 'turn'}
      event('summary', text)
    end

    private def stop_failure
      session.turn_active = false
      session.blockers = []
      session.pending_tools = {}
      session.error = payload['error'] || payload['message'] || 'Turn failed'
      event('error', session.error.to_s)
    end

    private def session_end
      session.turn_active = false
      session.blockers = []
      session.parked_at = @now.iso8601
      event('parked', "Session ended (#{payload['reason']})")
    end

    private def bash_milestone(command, failed:)
      case command
      when /\bgit\s+commit\b/
        return if failed

        subject = lookup.commit_subject(session.cwd)
        event('commit', subject || command.slice(0, 120))
      when /\bgh\s+pr\s+create\b/
        return if failed

        url = payload.dig('tool_response', 'stdout').to_s[%r{https://github\.com/\S+/pull/\d+}]
        session.pr_url = url if url
        event('pr', url ? "PR opened #{url}" : 'PR opened')
        link(IssueRef.from_text(url), source: 'tool') if url
      when /\bgh\s+issue\s+view\b/
        link(IssueRef.from_text(command), source: 'tool') unless failed
      when TEST_COMMAND
        outcome = failed ? "failed (#{payload['error']})" : 'passed'
        event('check', "#{command.lines.first.strip.slice(0, 100)} #{outcome}")
      end
    end

    private def record_edit(path)
      return if path.nil? || session.edited_files.include?(path)

      session.edited_files << path
      session.edited_files.shift while session.edited_files.size > MAX_EDITED_FILES
    end

    private def add_blocker(kind, tool_use_id, summary)
      session.blockers << {'kind' => kind, 'tool_use_id' => tool_use_id, 'summary' => summary, 'at' => @now.iso8601}
      event('blocked', "#{kind}: #{summary}")
    end

    private def clear_tool(id)
      return if id.nil?

      session.pending_tools.delete(id)
      session.blockers.reject! { it['tool_use_id'] == id }
    end

    # Links only an untracked session; an explicit `link` command overrides through Store directly.
    private def link(ref, source:)
      return if ref.nil? || session.issue

      session.issue = ref.merge('source' => source, 'at' => @now.iso8601)
      event('link', "Linked to #{ref.fetch('key')} (#{source})")
    end

    private def event(kind, text)
      @events << {'at' => @now.iso8601, 'kind' => kind, 'text' => text}
    end

    private def tool_digest(tool, input)
      Digest::SHA256.hexdigest(JSON.generate([tool, input]))
    end

    private def tool_target(input)
      return '' unless input.is_a?(Hash)

      (input['command'] || input['file_path'] || input['url'] || input.values.first).to_s.lines.first.to_s.strip.slice(0, 120)
    end

    private def question_summary(tool)
      input = payload['tool_input'] || {}
      case tool
      when 'AskUserQuestion' then input.dig('questions', 0, 'question').to_s.slice(0, 160)
      else 'Plan ready for approval'
      end
    end
  end
end
