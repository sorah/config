# frozen_string_literal: true

require 'fileutils'

module AgentBoard
  # File-backed state under $SORAH_AGENT_BOARD_HOME (default $XDG_STATE_HOME/sorah-agent-board).
  class Store
    TIMELINE_TAIL_BYTES = 64 * 1024

    def self.default_root
      ENV['SORAH_AGENT_BOARD_HOME'] ||
        File.join(ENV['XDG_STATE_HOME'] || File.join(Dir.home, '.local', 'state'), 'sorah-agent-board')
    end

    def initialize(root: self.class.default_root)
      @root = root
      File.umask(0o077)
      %w[sessions events locks archive cache inbox].each { FileUtils.mkdir_p(path(it)) }
    end

    attr_reader :root

    def path(*parts) = File.join(@root, *parts)

    # Yields the session under an exclusive lock, then saves it and appends any events the block returns.
    def update(id, now: Time.now)
      validate_id!(id)
      File.open(path('locks', "#{id}.lock"), File::RDWR | File::CREAT) do |lock|
        lock.flock(File::LOCK_EX)
        session = load(id) || Session.build(id:, now:)
        events = yield(session) || []
        save(session)
        append_events(id, events)
        session
      end
    end

    def load(id)
      validate_id!(id)
      file = path('sessions', "#{id}.json")
      return unless File.exist?(file)

      Session.from_h(JSON.parse(File.read(file)))
    end

    def sessions
      Dir[path('sessions', '*.json')].filter_map do |file|
        Session.from_h(JSON.parse(File.read(file)))
      rescue JSON::ParserError
        nil
      end
    end

    def timeline(id, limit: 50)
      file = path('events', "#{id}.jsonl")
      return [] unless File.exist?(file)

      data = File.open(file) do |f|
        f.seek([f.size - TIMELINE_TAIL_BYTES, 0].max)
        f.read
      end
      lines = data.lines
      lines.shift if data.bytesize >= TIMELINE_TAIL_BYTES
      lines.last(limit).filter_map do |line|
        JSON.parse(line)
      rescue JSON::ParserError
        nil
      end.reverse
    end

    def archive(id)
      FileUtils.mv(path('sessions', "#{id}.json"), path('archive', "#{id}.json"))
      move_if_exists(path('events', "#{id}.jsonl"), path('archive', "#{id}.jsonl"))
    end

    def unarchive(id)
      FileUtils.mv(path('archive', "#{id}.json"), path('sessions', "#{id}.json"))
      move_if_exists(path('archive', "#{id}.jsonl"), path('events', "#{id}.jsonl"))
    end

    def archived_ids
      Dir[path('archive', '*.json')].map { File.basename(it, '.json') }
    end

    # Newest mtime across everything a viewer renders, used by `watch` to detect changes.
    def change_marker
      files = Dir[path('sessions', '*.json')] + Dir[path('events', '*.jsonl')] + Dir[path('inbox', '**', '*.json')]
      [files.size, files.filter_map { mtime(it) }.max || 0.0]
    end

    # Files can vanish between the glob and the stat (atomic renames, archiving).
    private def mtime(file)
      File.mtime(file).to_f
    rescue Errno::ENOENT
      nil
    end

    WORKDAY_START_HOUR = 5

    # The chief's briefs key off when the user first shows up each workday (05:00 to 05:00).
    def record_user_activity(now = Time.now)
      file = path('chief', 'day.json')
      FileUtils.mkdir_p(File.dirname(file))
      workday = (now - (WORKDAY_START_HOUR * 3600)).strftime('%F')
      day = File.exist?(file) ? JSON.parse(File.read(file)) : {}
      return if day['workday'] == workday && day['first_activity_at']

      write_atomically(file, JSON.generate({'workday' => workday, 'first_activity_at' => now.iso8601, 'briefs' => {}}))
    end

    def workday
      file = path('chief', 'day.json')
      File.exist?(file) ? JSON.parse(File.read(file)) : nil
    end

    def mark_brief_delivered(kind, now = Time.now)
      day = workday or return
      day['briefs'][kind] = now.iso8601
      write_atomically(path('chief', 'day.json'), JSON.generate(day))
    end

    def relay_marker(id) = path('relaying', id)

    private def save(session)
      write_atomically(path('sessions', "#{session.id}.json"), JSON.pretty_generate(session.to_h))
    end

    private def append_events(id, events)
      return if events.empty?

      File.open(path('events', "#{id}.jsonl"), 'a') do |f|
        events.each { f.puts(JSON.generate(it)) }
      end
    end

    private def validate_id!(id)
      raise ArgumentError, "Invalid session id: #{id.inspect}" unless id.is_a?(String) && id.match?(/\A[\w-]{1,64}\z/)
    end

    private def move_if_exists(from, to)
      FileUtils.mv(from, to) if File.exist?(from)
    end

    def write_atomically(file, content)
      tmp = "#{file}.#{Process.pid}.tmp"
      File.write(tmp, content)
      File.rename(tmp, file)
    end
  end
end
