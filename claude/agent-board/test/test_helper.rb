# frozen_string_literal: true

require 'minitest/autorun'
require 'tmpdir'
require_relative '../lib/agent_board'

module AgentBoardTestHelper
  NOW = Time.iso8601('2026-11-18T12:00:00+09:00')

  StubLookup = Struct.new(:team_keys, :subject) do
    def commit_subject(_cwd) = subject
  end

  def payload(event, **fields)
    {'session_id' => 'sess-1', 'cwd' => '/work/repo.invalid', 'hook_event_name' => event}
      .merge(fields.transform_keys(&:to_s))
  end

  def apply(session, event, now: NOW, lookup: StubLookup.new([], 'Fix the gauge'), **fields)
    AgentBoard::State.new(lookup:).apply(session, payload(event, **fields), now:)
  end

  def new_session = AgentBoard::Session.build(id: 'sess-1', now: NOW)
end
