# frozen_string_literal: true

require 'open3'

module AgentBoard
  # tmux queries keyed by server socket, since pane IDs are only unique within one server.
  module Tmux
    # $TMUX is "socket_path,server_pid,session_index".
    def self.socket_from_env(env = ENV)
      env['TMUX']&.split(',')&.first
    end

    def self.run(socket, *args)
      out, status = Open3.capture2('tmux', '-S', socket, *args, err: File::NULL)
      status.success? ? out : nil
    rescue Errno::ENOENT
      nil
    end

    # Returns "session:window" for the pane, or nil when tmux is unavailable.
    def self.lane(socket, pane)
      return if socket.nil? || pane.nil?

      lane = run(socket, 'display-message', '-p', '-t', pane, '#{session_name}:#{window_name}')&.strip
      lane unless lane.nil? || lane.start_with?(':') || lane.end_with?(':')
    end

    # Pane IDs alive per socket. A socket whose server is gone maps to an empty set.
    def self.live_panes(sockets)
      sockets.uniq.to_h do |socket|
        out = File.socket?(socket) ? run(socket, 'list-panes', '-a', '-F', '#{pane_id}') : nil
        [socket, out ? out.split.to_set : Set.new]
      end
    end

    def self.switch_to(socket, pane)
      system('tmux', '-S', socket, 'switch-client', '-t', pane, exception: false)
    end
  end
end
