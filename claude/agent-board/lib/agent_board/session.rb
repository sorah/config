# frozen_string_literal: true

module AgentBoard
  # One Claude Code session as recorded from its hooks. Persisted as JSON; status is derived, never stored.
  Session = Struct.new(
    :id,
    :transcript_path,
    :cwd,
    :branch,
    :repo,
    :tmux_socket,
    :tmux_pane,
    :lane,
    :name,
    :goal,
    :title,
    :turn_active,
    :seen,
    :blockers,
    :pending_tools,
    :ask,
    :wait,
    :error,
    :plan,
    :last_report,
    :issue,
    :issue_announced,
    :pr_url,
    :edited_files,
    :parked_at,
    :started_at,
    :updated_at,
    :status_since,
    keyword_init: true,
  ) do
    STALE_AFTER = 10 * 60

    def self.build(id:, now:)
      new(
        id:,
        turn_active: false,
        seen: true,
        blockers: [],
        pending_tools: {},
        plan: nil,
        edited_files: [],
        started_at: now.iso8601,
        updated_at: now.iso8601,
      )
    end

    def self.from_h(hash)
      new(**hash.transform_keys(&:to_sym).slice(*members))
    end

    def status
      case
      when parked_at then :parked
      when error then :error
      when blockers.any? then :blocked
      when ask then :asking
      when wait then :waiting
      when turn_active then :working
      when !seen then :done
      else :idle
      end
    end

    def stale?(now)
      status == :working && now - Time.iso8601(updated_at) > STALE_AFTER
    end

    def short_id = id[0, 8]

    def display_name = name || tmux_session || File.basename(cwd || short_id)

    def tmux_session = lane&.split(':', 2)&.first

    def tmux_window = lane&.split(':', 2)&.last

    def tracked? = !issue.nil?

    def to_json(*) = to_h.to_json(*)
  end
end
