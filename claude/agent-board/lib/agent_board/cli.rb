# frozen_string_literal: true

require 'open3'
require 'optparse'

module AgentBoard
  # Subcommand dispatch for bin/sorah-agent-board.
  class CLI
    class Error < StandardError; end

    USAGE = <<~USAGE
      Usage: sorah-agent-board COMMAND [ARGS]

      Agent commands (run from inside a Claude Code session):
        report TEXT                 record a progress note
        ask TEXT                    you need the user's answer to continue
        wait --on WHO TEXT          you are blocked on someone other than the user
        plan STEP...                declare 3-7 steps; indent a step with two spaces to nest it
        step N done|doing|todo      update step N (1-based)
        link [--agent AGENT] KEY_OR_URL
                                    bind this (or another) session to a Linear or GitHub issue

        tell chief TEXT             leave a non-blocking note for the chief of staff

      Chief-of-staff commands:
        send AGENT TEXT             paste a prompt into an agent waiting at its prompt; confirms receipt
        resume AGENT                reopen a parked session in a new tmux window
        clear AGENT                 drop a stale dialog/turn after Esc (Esc fires no hook)
        dispatch NAME --cwd DIR --goal TEXT [--issue REF] -- PROMPT
                                    start a new agent in a window on the default tmux server
        watch --for chief           block until something needs triage; prints what changed as JSON
        chief ensure [--fresh]      start the chief session unless it is running
        chief attach                attach to the chief's tmux server
        chief supervise             keep the chief running; fresh session daily at 05:00 (systemd)

      Viewer commands:
        snapshot [--json]           print the board
        count                       needs-you count for the tmux status line
        watch [--json]              block until something changes; --json streams snapshots
        seen --socket S --pane P    mark a finished turn as seen
        tui                         interactive board (Bun); --fixture FILE renders a saved snapshot
        archive AGENT | unarchive AGENT
                                    put a session away (or back); nothing is archived automatically
        hook                        Claude Code hook entry point (reads the payload on stdin)
    USAGE

    def self.run(argv)
      new(argv).run
    rescue Error, OptionParser::ParseError => e
      warn("sorah-agent-board: #{e.message}")
      exit(1)
    end

    def initialize(argv)
      @argv = argv.dup
      @command = @argv.shift
    end

    def run
      case @command
      when 'hook'
        output = Hook.new(store:).call($stdin.read)
        puts(output) if output
      when 'report' then update_self { |s, now| report(s, now) }
      when 'ask' then update_self { |s, now| ask(s, now) }
      when 'wait' then update_self { |s, now| wait(s, now) }
      when 'plan' then update_self { |s, now| plan(s, now) }
      when 'step' then update_self { |s, now| step(s, now) }
      when 'link' then link_command
      when 'snapshot' then snapshot
      when 'count' then count
      when 'watch' then watch
      when 'send' then relay
      when 'tell' then tell
      when 'resume' then resume
      when 'clear' then clear
      when 'dispatch' then dispatch
      when 'chief' then chief
      when 'seen' then seen
      when 'archive' then archive
      when 'unarchive' then unarchive
      when 'tui' then tui
      when nil, 'help', '-h', '--help' then puts(USAGE)
      else raise Error, "unknown command: #{@command}\n#{USAGE}"
      end
    end

    private def store = @store ||= Store.new

    private def text_arg
      text = @argv.join(' ').strip
      raise Error, "#{@command}: text is required" if text.empty?

      text
    end

    private def update_self
      id = self_session_id
      store.update(id) { |s| yield(s, Time.now) }
      puts('ok')
    end

    private def self_session_id
      return ENV['SORAH_AGENT_BOARD_SESSION'] if ENV['SORAH_AGENT_BOARD_SESSION']

      socket = Tmux.socket_from_env
      pane = ENV['TMUX_PANE']
      found = store.sessions.find { it.parked_at.nil? && it.tmux_socket == socket && it.tmux_pane == pane } if pane
      found&.id or raise Error, 'cannot tell which session this is (no SORAH_AGENT_BOARD_SESSION, no matching tmux pane)'
    end

    private def report(session, now)
      text = text_arg
      session.last_report = {'text' => text, 'at' => now.iso8601, 'source' => 'agent'}
      [event(now, 'report', text)]
    end

    private def ask(session, now)
      session.ask = text_arg
      [event(now, 'ask', session.ask)]
    end

    private def wait(session, now)
      on = nil
      OptionParser.new { it.on('--on WHO') { |v| on = v } }.parse!(@argv)
      raise Error, 'wait: --on WHO is required' if on.nil?

      session.wait = {'on' => on, 'text' => text_arg}
      [event(now, 'wait', "#{on}: #{session.wait.fetch('text')}")]
    end

    private def plan(session, now)
      raise Error, 'plan: at least one step is required' if @argv.empty?

      steps = @argv.map do |raw|
        {'title' => raw.strip, 'status' => 'todo', 'depth' => raw[/\A */].size / 2}
      end
      session.plan = {'steps' => steps, 'started_at' => now.iso8601}
      [event(now, 'plan', "Plan: #{steps.size} steps")]
    end

    private def step(session, now)
      index, status = @argv
      raise Error, 'step: no plan declared; run `plan` first' if session.plan.nil?
      raise Error, 'step: usage: step N done|doing|todo' unless index&.match?(/\A\d+\z/) && %w[done doing todo].include?(status)

      step = session.plan.fetch('steps')[index.to_i - 1] or raise Error, "step: no step #{index}"
      step['status'] = status
      [event(now, 'step', "#{step.fetch('title')} → #{status}")]
    end

    # Without --agent the caller links its own session; with it, the chief links another agent, whose
    # hook then tells that agent at its next prompt or tool call.
    private def link_command
      agent = nil
      OptionParser.new { it.on('--agent AGENT') { |v| agent = v } }.parse!(@argv)
      ref = IssueRef.parse_explicit(text_arg) or raise Error, "link: not an issue key or URL: #{text_arg}"
      id = agent ? find_agent(agent).id : self_session_id
      store.update(id) do |s|
        now = Time.now
        s.issue = ref.merge('source' => agent ? 'chief' : 'explicit', 'at' => now.iso8601)
        s.issue_announced = agent ? nil : ref.fetch('key')
        [event(now, 'link', "Linked to #{ref.fetch('key')}")]
      end
      puts('ok')
    end

    private def snapshot
      data = Snapshot.new(store:).to_h
      return puts(JSON.generate(data)) if @argv.include?('--json')

      data.fetch('groups').each do |group|
        next if group.fetch('agents').empty?

        puts("#{group.fetch('title').upcase} #{group.fetch('agents').size}")
        group.fetch('agents').each do |a|
          links = [a.dig('pr', 'url'), a.dig('issue', 'key')].compact.join(' ')
          puts(format('  %-20s %-8s %s %s', a.fetch('name'), a.fetch('short_id'), a.fetch('headline'), links).rstrip)
        end
      end
    end

    private def count
      n = Snapshot.new(store:, pull_requests: false).needs_you_count
      print("⚑#{n} ") if n.positive?
    end

    private def seen
      socket = pane = nil
      OptionParser.new do |o|
        o.on('--socket PATH') { socket = it }
        o.on('--pane ID') { pane = it }
      end.parse!(@argv)
      raise Error, 'seen: --socket and --pane are required' if socket.nil? || pane.nil?

      store.record_user_activity unless File.basename(socket) == Chief::SERVER

      store.sessions.each do |s|
        next unless s.tmux_socket == socket && s.tmux_pane == pane && s.status == :done

        store.update(s.id) do |u|
          u.seen = true
          u.status_since = Time.now.iso8601
          nil
        end
      end
    end

    private def watch
      case
      when @argv.delete('--json') then Watch.new(store:).stream
      when @argv.include?('--for')
        raise Error, 'watch: only `--for chief` is supported' unless @argv.last == 'chief'

        puts(JSON.generate(ChiefWatch.new(store:).once))
      else Watch.new(store:).once
      end
    end

    private def relay
      target = find_agent(@argv.shift.to_s)
      text = text_arg
      from = ENV['SORAH_AGENT_BOARD_SESSION']&.then { store.load(it)&.display_name } || 'user'
      Relay.new(store:).deliver(target, text, from:)
      puts("delivered to #{target.display_name}")
    rescue Relay::Refused, Relay::Stalled => e
      raise Error, "send: #{e.message}"
    end

    private def tell
      recipient = @argv.shift
      raise Error, 'tell: only `tell chief TEXT` is supported' unless recipient == 'chief'

      text = text_arg
      from = ENV['SORAH_AGENT_BOARD_SESSION']&.then { store.load(it)&.display_name } || 'user'
      dir = store.path('inbox', 'chief')
      FileUtils.mkdir_p(dir)
      now = Time.now
      store.write_atomically(File.join(dir, "#{now.strftime('%Y%m%dT%H%M%S%N')}.json"),
                             JSON.generate({'from' => from, 'text' => text, 'at' => now.iso8601}))
      puts('ok')
    end

    private def resume
      session = find_agent(text_arg)
      raise Error, "resume: #{session.display_name} is #{session.status}, not parked" unless session.status == :parked
      raise Error, 'resume: session has no recorded cwd' unless session.cwd && File.directory?(session.cwd)

      env = {'TMUX' => nil, 'TMUX_PANE' => nil}
      socket = session.tmux_socket if session.tmux_socket && File.socket?(session.tmux_socket)
      tmux = socket ? ['tmux', '-S', socket] : ['tmux']
      command = "SORAH_AGENT_BOARD_NAME=#{session.display_name} exec #{['claude', '--resume', session.id].shelljoin}"
      system(env, *tmux, 'new-window', '-n', session.display_name, '-c', session.cwd,
             ['zsh', '-lic', command].shelljoin, exception: true)
      puts("resumed #{session.display_name}")
    end

    private def clear
      session = find_agent(text_arg)
      store.update(session.id) do |s|
        s.blockers = []
        s.turn_active = false
        s.pending_tools = {}
        [event(Time.now, 'cleared', 'Stale dialog or turn cleared by the user')]
      end
      puts("cleared #{session.display_name}")
    end

    private def dispatch
      opts = {}
      OptionParser.new do |o|
        o.on('--cwd DIR') { opts[:cwd] = it }
        o.on('--goal TEXT') { opts[:goal] = it }
        o.on('--issue REF') { opts[:issue] = it }
      end.parse!(@argv)
      name = @argv.shift
      prompt = @argv.join(' ').strip
      raise Error, 'dispatch: usage: dispatch NAME --cwd DIR --goal TEXT [--issue REF] -- PROMPT' if [name, opts[:cwd], opts[:goal]].any?(&:nil?) || prompt.empty?

      Dispatch.new(store:).launch(name:, cwd: File.expand_path(opts.fetch(:cwd)), goal: opts.fetch(:goal), issue: opts[:issue], prompt:)
      puts("dispatched #{name}")
    end

    private def chief
      case @argv.shift
      when 'ensure' then puts(Chief.new(store:).ensure_running(fresh: @argv.include?('--fresh')))
      when 'attach' then Chief.new(store:).attach
      when 'supervise' then Chief.new(store:).supervise
      else raise Error, 'chief: usage: chief ensure [--fresh] | chief attach | chief supervise'
      end
    end

    private def tui
      dir = File.join(ROOT, 'tui')
      bun = find_bun or raise Error, 'tui: bun not found (PATH or `mise which bun`)'
      unless File.directory?(File.join(dir, 'node_modules'))
        system(bun, 'install', '--frozen-lockfile', chdir: dir, exception: true)
      end
      exec(bun, 'run', File.join(dir, 'src', 'main.tsx'), *@argv)
    end

    # tmux popups inherit the server's PATH, which may predate mise activation.
    private def find_bun
      ENV.fetch('PATH', '').split(File::PATH_SEPARATOR).map { File.join(it, 'bun') }.find { File.executable?(it) } ||
        [File.join(Dir.home, '.local', 'bin', 'mise'), 'mise'].lazy.filter_map do |mise|
          out, status = Open3.capture2(mise, 'which', 'bun', err: File::NULL)
          out.strip if status.success?
        rescue Errno::ENOENT
          nil
        end.first
    end

    private def archive
      session = find_agent(text_arg)
      store.archive(session.id)
      puts("archived #{session.display_name} (#{session.short_id})")
    end

    private def unarchive
      query = text_arg
      ids = store.archived_ids.select { it.start_with?(query) }
      raise Error, "unarchive: #{ids.empty? ? 'no' : 'ambiguous'} archived session matching #{query}" unless ids.size == 1

      store.unarchive(ids.first)
      puts("unarchived #{ids.first[0, 8]}")
    end

    private def find_agent(query)
      sessions = store.sessions
      matches = sessions.select { it.display_name == query }
      matches = sessions.select { it.id.start_with?(query) } if matches.empty?
      raise Error, "no session matching #{query}" if matches.empty?
      raise Error, "ambiguous: #{matches.map { "#{it.display_name} (#{it.short_id})" }.join(', ')}" if matches.size > 1

      matches.first
    end

    private def event(now, kind, text) = {'at' => now.iso8601, 'kind' => kind, 'text' => text}
  end
end
