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
      @labels = labels(agents)
      prs = @pull_requests ? PullRequests.new(store: @store, now: @now).for_sessions(agents) : {}
      @titles = @pull_requests ? PullRequests.new(store: @store, now: @now).issue_titles(agents) : {}
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
        'label' => @labels.fetch(session.id),
        'title' => title(session),
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
        'last_report' => report(session.last_report),
        'issue' => issue(session),
        'pr' => pr,
        'edited_files' => session.edited_files.size,
        'timeline' => @store.timeline(session.id, limit: @timeline_limit),
        'tmux' => {'socket' => session.tmux_socket, 'pane' => session.tmux_pane},
      }
    end

    private def report(last_report)
      return if last_report.nil?

      text = Text.plain(last_report.fetch('text'))
      last_report.merge('text' => text, 'brief' => Text.brief(text))
    end

    # An explicit name, else the tmux session, plus the window when two agents share a session.
    private def labels(agents)
      shared = agents.reject(&:name).group_by(&:tmux_session).select { |key, list| key && list.size > 1 }.keys
      agents.to_h do |s|
        label = s.name || (shared.include?(s.tmux_session) ? s.lane : s.display_name)
        [s.id, label]
      end
    end

    TITLE_WORDS = 6

    # A few words for the work: the issue title, the agent's own title, or the start of its first prompt.
    private def title(session)
      text = issue(session)&.fetch('title') || session.title || branch_words(session)
      return if text.nil?

      words = text.split
      words.size > TITLE_WORDS ? "#{words.first(TITLE_WORDS).join(' ')}…" : text
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

    # Issue title from the chief's brief, else the GitHub title fetched by code.
    private def issue(session)
      issue = session.issue
      return if issue.nil?

      key = issue.fetch('key')
      cached = @store.path('cache', 'issues', "#{key.tr('/#', '__')}.json")
      title = File.exist?(cached) ? JSON.parse(File.read(cached))['title'] : nil
      title ||= @titles&.fetch(key, nil)
      others = Array(session.refs).map { it['key'] }.reject { it == key }
      short = [short_key(key), *others.first(1).map { short_key(it) }].join(' ')
      issue.slice('key', 'url', 'tracker', 'source').merge('title' => title, 'short' => short, 'related' => others)
    end

    # owner/repo#N is too long for a column, and a bare #N is ambiguous, so repo#N.
    private def short_key(key)
      return key unless (m = key.match(%r{\A[^/]+/([^#]+)#(\d+)\z}))

      "#{m[1]}##{m[2]}"
    end

    BRANCH_NOISE = %r{\A(?:[^/]+/)?(?:[a-z][a-z0-9]{0,9}-\d+-|\d+-)?}

    # sorah/web-420-fix-gauge-window -> "fix gauge window"
    private def branch_words(session)
      branch = session.branch
      return if branch.nil? || %w[main master develop].include?(branch)

      words = branch.sub(BRANCH_NOISE, '').tr('-_/', '   ').strip
      words.empty? ? nil : words
    end
  end
end
