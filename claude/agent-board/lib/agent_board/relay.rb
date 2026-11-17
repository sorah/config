# frozen_string_literal: true

require 'securerandom'
require 'shellwords'

module AgentBoard
  # Delivers a prompt into an agent's tmux pane, only while the agent is waiting at its prompt.
  class Relay
    class Refused < StandardError; end
    class Stalled < StandardError; end

    ACCEPTING = %i[done idle asking waiting error].freeze
    CONFIRM_TIMEOUT = 5

    def initialize(store:)
      @store = store
    end

    def deliver(session, text, from:)
      refusal_for(session)&.then { raise Refused, it }

      sent_at = Time.now
      # Marks the coming UserPromptSubmit as relayed, so it does not count as the user being active.
      marker = @store.relay_marker(session.id)
      FileUtils.mkdir_p(File.dirname(marker))
      File.write(marker, sent_at.iso8601)
      begin
        paste(session.tmux_socket, session.tmux_pane, text)
        @store.update(session.id) do
          [{'at' => sent_at.iso8601, 'kind' => 'message', 'text' => "From #{from}: #{text}"}]
        end
        confirm!(session, sent_at)
      ensure
        FileUtils.rm_f(marker)
      end
    end

    private def refusal_for(session)
      case
      when session.tmux_socket.nil? || session.tmux_pane.nil? then 'agent has no recorded tmux pane'
      when session.blockers.any? then "agent is showing a dialog (#{session.blockers.first.fetch('kind')}); answer it in the pane"
      when !ACCEPTING.include?(session.status) then "agent is #{session.status}, not waiting at its prompt"
      when !Tmux.live_panes([session.tmux_socket]).fetch(session.tmux_socket).include?(session.tmux_pane)
        'agent pane is gone'
      end
    end

    # A bracketed paste keeps newlines inside the prompt instead of submitting early.
    private def paste(socket, pane, text)
      buffer = "agent-board-#{SecureRandom.hex(4)}"
      IO.popen(['tmux', '-S', socket, 'load-buffer', '-b', buffer, '-'], 'w') { it.write(text) }
      raise Refused, 'tmux load-buffer failed' unless $?.success?

      system('tmux', '-S', socket, 'paste-buffer', '-p', '-d', '-b', buffer, '-t', pane, exception: true)
      sleep(0.2)
      system('tmux', '-S', socket, 'send-keys', '-t', pane, 'Enter', exception: true)
    end

    # UserPromptSubmit from the target is the receipt; without it the prompt may still sit unsent.
    private def confirm!(session, sent_at)
      deadline = Time.now + CONFIRM_TIMEOUT
      while Time.now < deadline
        received = @store.timeline(session.id, limit: 10).any? do
          it.fetch('kind') == 'prompt' && Time.iso8601(it.fetch('at')) >= sent_at.floor
        end
        return if received

        sleep(0.25)
      end
      raise Stalled, 'no UserPromptSubmit within 5s; check the pane before retrying'
    end
  end
end
