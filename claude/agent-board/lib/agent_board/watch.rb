# frozen_string_literal: true

module AgentBoard
  # Change detection by polling mtimes; cheap enough at this scale and needs no native extension.
  class Watch
    INTERVAL = 0.5
    HEARTBEAT = 30

    def initialize(store:, out: $stdout)
      @store = store
      @out = out
    end

    def once
      start = @store.change_marker
      sleep(INTERVAL) while @store.change_marker == start
    end

    # Emits one snapshot JSON per line on every change, and at least every HEARTBEAT seconds.
    def stream
      marker = nil
      emitted_at = Time.at(0)
      loop do
        current = @store.change_marker
        now = Time.now
        if current != marker || now - emitted_at >= HEARTBEAT
          @out.puts(JSON.generate(Snapshot.new(store: @store, now:).to_h))
          @out.flush
          # Parking vanished panes writes to the store; count that write as seen.
          marker = @store.change_marker
          emitted_at = now
        end
        sleep(INTERVAL)
      end
    rescue Errno::EPIPE
      nil
    end
  end
end
