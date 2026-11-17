# frozen_string_literal: true

module AgentBoard
  # Whether the user is at the chief right now. Actions that can carry external content into agents
  # or out of the machine require it when the chief invokes them, so an injected instruction read
  # while unattended cannot trigger them.
  module Presence
    WINDOW = 15 * 60
    # Turns the harness or the supervisor starts, which the user did not type.
    AUTOMATED_PROMPT = /\A\s*(?:<(?:task-notification|system-reminder|agent-message)|\[SYSTEM NOTIFICATION)|by the supervisor; the user is not here yet/

    def self.file(store) = store.path('chief', 'presence.json')

    def self.user_prompt?(prompt) = !prompt.to_s.match?(AUTOMATED_PROMPT)

    def self.record(store, now = Time.now)
      FileUtils.mkdir_p(File.dirname(file(store)))
      store.write_atomically(file(store), JSON.generate({'at' => now.iso8601}))
    end

    def self.present?(store, now = Time.now)
      return false unless File.exist?(file(store))

      now - Time.iso8601(JSON.parse(File.read(file(store))).fetch('at')) <= WINDOW
    end

    # The caller is the chief when an ancestor process carries the chief's environment. Reading it
    # from /proc keeps a command from claiming otherwise through its own environment.
    def self.chief_caller?(pid = Process.ppid)
      return ENV['SORAH_AGENT_BOARD_NAME'] == Snapshot::CHIEF_NAME unless File.directory?('/proc')

      seen = 0
      while pid && pid > 1 && seen < 64
        environ = File.binread("/proc/#{pid}/environ").split("\0")
        return true if environ.include?("SORAH_AGENT_BOARD_NAME=#{Snapshot::CHIEF_NAME}")

        pid = File.read("/proc/#{pid}/stat")[/\) \S (\d+)/, 1]&.to_i
        seen += 1
      end
      false
    rescue Errno::ENOENT, Errno::EACCES
      false
    end

    def self.require!(store, action)
      return unless chief_caller?
      return if present?(store)

      raise CLI::Error, "#{action}: needs the user; the chief may only do this within #{WINDOW / 60} minutes of a message from them"
    end
  end
end
