# frozen_string_literal: true

require 'json'
require 'time'

# Tracks Claude Code sessions running in tmux from their hook events.
module AgentBoard
  ROOT = File.expand_path('..', __dir__)
end

require_relative 'agent_board/text'
require_relative 'agent_board/session'
require_relative 'agent_board/issue_ref'
require_relative 'agent_board/state'
require_relative 'agent_board/store'
require_relative 'agent_board/tmux'
require_relative 'agent_board/hook'
require_relative 'agent_board/pull_requests'
require_relative 'agent_board/snapshot'
require_relative 'agent_board/watch'
require_relative 'agent_board/relay'
require_relative 'agent_board/chief'
require_relative 'agent_board/presence'
require_relative 'agent_board/intake'
require_relative 'agent_board/guard'
require_relative 'agent_board/summarizer'
require_relative 'agent_board/cli'
