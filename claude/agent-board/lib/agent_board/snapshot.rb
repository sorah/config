# frozen_string_literal: true

module AgentBoard
  # Grouped, render-ready view of all sessions. The JSON shape is mirrored by tui/src/snapshot.ts.
  class Snapshot
    CHIEF_NAME = 'chief-of-staff'
    GROUPS = [
      ['needs_you', 'Needs you', %i[blocked asking error done]],
      ['waiting', 'Waiting on others', %i[waiting]],
      ['working', 'Working', %i[working]],
      ['idle', 'Idle', %i[idle]],
      ['parked', 'Parked', %i[parked]],
    ].freeze
    NEEDS_YOU = GROUPS.first.last

    def initialize(store:, now: Time.now, pull_requests: true, timeline_limit: 30)
      @store = store
      @now = now
      @pull_requests = pull_requests
      @timeline_limit = timeline_limit
    end

    def sessions
      @sessions ||= park_vanished(@store.sessions)
    end

    def to_h
      chief, agents = sessions.partition { it.name == CHIEF_NAME }
      prs = @pull_requests ? PullRequests.new(store: @store, now: @now).for_sessions(agents) : {}
      groups = GROUPS.map do |key, title, statuses|
        members = agents.select { statuses.include?(it.status) }
        {'key' => key, 'title' => title, 'agents' => sort(key, members).map { Text.deep_clean(agent(it, prs[it.id])) }}
      end
      {
        'generated_at' => @now.iso8601,
        'counts' => groups.to_h { [it.fetch('key'), it.fetch('agents').size] },
        'chief' => chief.max_by(&:updated_at)&.then { {'status' => it.status.to_s, 'since' => it.status_since} },
        'groups' => groups,
      }
    end

    def needs_you_count
      sessions.count { NEEDS_YOU.include?(it.status) && it.name != CHIEF_NAME }
    end

    # A pane that disappeared without SessionEnd (killed window, tmux restart) parks its session.
    private def park_vanished(sessions)
      candidates = sessions.select { it.parked_at.nil? && it.tmux_socket && it.tmux_pane }
      live = Tmux.live_panes(candidates.map(&:tmux_socket))
      sessions.map do |s|
        next s unless candidates.include?(s) && !live.fetch(s.tmux_socket).include?(s.tmux_pane)

        @store.update(s.id, now: @now) do |u|
          u.parked_at = @now.iso8601
          u.turn_active = false
          u.blockers = []
          u.status_since = @now.iso8601
          [{'at' => @now.iso8601, 'kind' => 'parked', 'text' => 'tmux pane is gone'}]
        end
      end
    end

    private def sort(key, members)
      case key
      when 'needs_you', 'waiting' then members.sort_by { it.status_since.to_s }
      else members.sort_by { it.updated_at.to_s }.reverse
      end
    end

    private def agent(session, pr)
      {
        'id' => session.id,
        'short_id' => session.short_id,
        'name' => session.display_name,
        'lane' => session.lane,
        'cwd' => session.cwd,
        'branch' => session.branch,
        'status' => session.status.to_s,
        'stale' => session.stale?(@now),
        'since' => session.status_since,
        'updated_at' => session.updated_at,
        'headline' => headline(session),
        'goal' => session.goal,
        'blockers' => session.blockers.map { it.slice('kind', 'summary', 'at') },
        'ask' => session.ask,
        'wait' => session.wait,
        'error' => session.error,
        'plan' => plan(session.plan),
        'last_report' => session.last_report,
        'issue' => issue(session.issue),
        'pr' => pr,
        'edited_files' => session.edited_files.size,
        'timeline' => @store.timeline(session.id, limit: @timeline_limit),
        'tmux' => {'socket' => session.tmux_socket, 'pane' => session.tmux_pane},
      }
    end

    private def headline(session)
      case session.status
      when :blocked
        blocker = session.blockers.first
        "you: #{blocker.fetch('kind')} — #{blocker.fetch('summary')}"
      when :asking then "you: #{session.ask}"
      when :waiting then "#{session.wait.fetch('on')}: #{session.wait.fetch('text')}"
      when :error then "error: #{session.error}"
      when :parked then next_step(session.plan) || session.goal || '(no goal recorded)'
      else session.goal || '(no goal recorded)'
      end
    end

    private def next_step(plan)
      step = plan&.fetch('steps')&.find { it.fetch('status') != 'done' }
      step && "next: #{step.fetch('title')}"
    end

    private def plan(plan)
      return if plan.nil?

      steps = plan.fetch('steps')
      plan.merge('done' => steps.count { it.fetch('status') == 'done' }, 'total' => steps.size)
    end

    private def issue(issue)
      return if issue.nil?

      cached = @store.path('cache', 'issues', "#{issue.fetch('key').tr('/#', '__')}.json")
      title = File.exist?(cached) ? JSON.parse(File.read(cached))['title'] : nil
      issue.slice('key', 'url', 'tracker', 'source').merge('title' => title)
    end
  end
end
