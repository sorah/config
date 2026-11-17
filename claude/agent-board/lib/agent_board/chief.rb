# frozen_string_literal: true

require 'securerandom'
require 'shellwords'

module AgentBoard
  # Lifecycle of the chief-of-staff session, hosted on its own tmux server so the default server's
  # attach behaviour (zsh/dot.zshrc) never sees it.
  class Chief
    SERVER = 'sorah-chief'
    SESSION = 'chief'
    NAME = Snapshot::CHIEF_NAME
    PREFIX = 'C-q'
    SETTINGS = File.join(ROOT, 'chief-settings.json')
    COMMAND = '/sorah-chief:chief-of-staff'

    def initialize(store:)
      @store = store
    end

    def running?
      out, status = Open3.capture2('tmux', '-L', SERVER, 'list-panes', '-t', SESSION, '-F', '#{pane_dead}', err: File::NULL)
      status.success? && out.split.include?('0')
    rescue Errno::ENOENT
      false
    end

    # Starts the chief when it is not running. Resumes its last session unless fresh.
    def ensure_running(fresh: false)
      if fresh
        system('tmux', '-L', SERVER, 'kill-session', '-t', SESSION, err: File::NULL)
      elsif running?
        return :running
      end

      resume_id = fresh ? nil : last_session_id
      claude = ['claude', '--name', NAME, '--remote-control', NAME, '--settings', SETTINGS]
      claude += ['--resume', resume_id] if resume_id
      claude << "#{COMMAND} #{resume_id ? 'resumed' : 'started'} by the supervisor; the user is not here yet"
      inner = "SORAH_AGENT_BOARD_NAME=#{NAME} exec #{claude.shelljoin}"
      # An interactive login zsh gives the chief the same PATH, mise tools and agents as a terminal.
      shell = ['zsh', '-lic', inner].shelljoin

      system('tmux', '-L', SERVER, 'kill-session', '-t', SESSION, err: File::NULL)
      system('tmux', '-L', SERVER, '-f', File.join(Dir.home, '.tmux.conf'),
             'new-session', '-d', '-s', SESSION, '-n', SESSION, '-c', Dir.home, shell, exception: true)
      system('tmux', '-L', SERVER, 'set', '-g', 'prefix', PREFIX, exception: true)
      system('tmux', '-L', SERVER, 'set', '-g', 'status-left', '#[bg=colour54,fg=white] chief ', exception: true)
      resume_id ? :resumed : :started
    end

    def attach
      exec({'TMUX' => nil}, 'tmux', '-L', SERVER, 'attach-session', '-t', SESSION)
    end

    SUPERVISE_INTERVAL = 60
    ROTATE_HOUR = 5

    # Long-running loop for the systemd unit: keep the chief up, and start a fresh session once a
    # day so its context is rebuilt from files instead of growing without bound.
    def supervise
      state_file = @store.path('chief', 'supervisor.json')
      FileUtils.mkdir_p(File.dirname(state_file))
      loop do
        now = Time.now
        state = File.exist?(state_file) ? JSON.parse(File.read(state_file)) : {}
        today = now.strftime('%F')
        if now.hour >= ROTATE_HOUR && state['rotated_on'] != today
          ensure_running(fresh: true)
          @store.write_atomically(state_file, JSON.generate(state.merge('rotated_on' => today)))
        else
          ensure_running
        end
        sleep(SUPERVISE_INTERVAL)
      end
    end

    private def last_session_id
      @store.sessions.select { it.name == NAME }.max_by(&:updated_at)&.id
    end
  end

  # Agent launches requested by the chief, onto the user's default tmux server.
  class Dispatch
    def initialize(store:)
      @store = store
    end

    def launch(name:, cwd:, goal:, prompt:, issue: nil)
      raise CLI::Error, "dispatch: invalid name #{name.inspect}" unless name.match?(/\A[a-z][a-z0-9_-]{0,31}\z/)
      raise CLI::Error, "dispatch: no such directory #{cwd}" unless File.directory?(cwd)

      id = SecureRandom.uuid
      FileUtils.mkdir_p(@store.path('pending'))
      @store.write_atomically(@store.path('pending', "#{id}.json"), JSON.generate({name:, goal:, issue:}.compact))
      command = "SORAH_AGENT_BOARD_DISPATCH=#{id} SORAH_AGENT_BOARD_NAME=#{name} exec #{['claude', prompt].shelljoin}"
      # Without TMUX in the environment, tmux targets the default server rather than the chief's own.
      env = {'TMUX' => nil, 'TMUX_PANE' => nil}
      _, status = Open3.capture2(env, 'tmux', 'has-session', err: File::NULL)
      raise CLI::Error, 'dispatch: the default tmux server is not running; start tmux first' unless status.success?

      system(env, 'tmux', 'new-window', '-d', '-n', name, '-c', cwd, ['zsh', '-lic', command].shelljoin, exception: true)
      id
    end
  end

  # Wakes the chief on events worth triage. The cursor persists so nothing is missed between runs.
  class ChiefWatch
    TRIGGER_STATUSES = %w[blocked asking error done waiting parked].freeze

    def initialize(store:)
      @store = store
      @cursor_file = @store.path('chief', 'watch-cursor.json')
      FileUtils.mkdir_p(@store.path('chief'))
      FileUtils.mkdir_p(@store.path('inbox', 'chief', 'read'))
    end

    # One watcher at a time: each inbox message is consumed by whichever watcher reads it first.
    def once
      lock = File.open(@store.path('chief', 'watch.lock'), File::RDWR | File::CREAT)
      return {'error' => 'another `watch --for chief` is already running'} unless lock.flock(File::LOCK_EX | File::LOCK_NB)

      wait_for_triage
    ensure
      lock&.close
    end

    private def wait_for_triage
      # A fresh chief reads the whole board at startup, so a missing cursor starts from the current state.
      cursor = File.exist?(@cursor_file) ? JSON.parse(File.read(@cursor_file)) : nil
      loop do
        snapshot = Snapshot.new(store: @store, pull_requests: false)
        statuses = snapshot.sessions.reject { it.name == Snapshot::CHIEF_NAME }.to_h { [it.id, it.status.to_s] }
        if cursor.nil?
          cursor = statuses
          @store.write_atomically(@cursor_file, JSON.generate(statuses))
        end
        changes = statuses.filter_map do |id, status|
          next if cursor[id] == status || !TRIGGER_STATUSES.include?(status)

          session = snapshot.sessions.find { it.id == id }
          {'agent' => session.display_name, 'id' => id, 'status' => status, 'was' => cursor[id]}
        end
        messages = read_inbox
        brief = due_brief(Time.now)
        if changes.any? || messages.any? || brief
          @store.write_atomically(@cursor_file, JSON.generate(statuses))
          @store.mark_brief_delivered(brief) if brief
          return {'changes' => changes, 'messages' => messages, 'brief' => brief}
        end
        sleep(Watch::INTERVAL * 2)
      end
    end

    FOLLOWUP_AFTER = 6 * 3600

    # "start" once the user first shows up in a workday, "followup" six hours later.
    private def due_brief(now)
      day = @store.workday
      return if day.nil? || day['first_activity_at'].nil?

      briefs = day.fetch('briefs')
      return 'start' unless briefs['start']
      return 'followup' if !briefs['followup'] && now - Time.iso8601(day['first_activity_at']) >= FOLLOWUP_AFTER

      nil
    end

    private def read_inbox
      Dir[@store.path('inbox', 'chief', '*.json')].sort.map do |file|
        message = JSON.parse(File.read(file))
        FileUtils.mv(file, @store.path('inbox', 'chief', 'read', File.basename(file)))
        message
      end
    end
  end
end
