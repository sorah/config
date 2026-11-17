# frozen_string_literal: true

require_relative 'test_helper'

class StoreAndCliTest < Minitest::Test
  include AgentBoardTestHelper

  def setup
    @dir = Dir.mktmpdir
    @store = AgentBoard::Store.new(root: @dir)
  end

  def teardown
    FileUtils.remove_entry(@dir)
  end

  def test_update_persists_session_and_events
    @store.update('sess-1', now: NOW) do |s|
      s.goal = 'g'
      [{'at' => NOW.iso8601, 'kind' => 'report', 'text' => 'hello'}]
    end

    assert_equal 'g', @store.load('sess-1').goal
    assert_equal ['hello'], @store.timeline('sess-1').map { it.fetch('text') }
  end

  def test_rejects_path_like_session_ids
    assert_raises(ArgumentError) { @store.load('../etc') }
  end

  def test_archive_round_trip
    @store.update('sess-1', now: NOW) { nil }
    @store.archive('sess-1')

    assert_empty @store.sessions
    assert_equal ['sess-1'], @store.archived_ids

    @store.unarchive('sess-1')

    assert_equal ['sess-1'], @store.sessions.map(&:id)
  end

  def test_agent_commands_drive_status_and_plan
    with_env('SORAH_AGENT_BOARD_HOME' => @dir, 'SORAH_AGENT_BOARD_SESSION' => 'sess-1') do
      cli('plan', 'Reproduce', 'Fix', '  Write the test', 'Ship')
      cli('step', '1', 'done')
      cli('ask', 'Dec 1 or Jan 15?')
    end
    s = @store.load('sess-1')

    assert_equal :asking, s.status
    assert_equal [0, 0, 1, 0], s.plan.fetch('steps').map { it.fetch('depth') }
    assert_equal 'done', s.plan.dig('steps', 0, 'status')

    snapshot = AgentBoard::Snapshot.new(store: @store, pull_requests: false).to_h
    agent = snapshot.fetch('groups').first.fetch('agents').first

    assert_equal 'you: Dec 1 or Jan 15?', agent.fetch('headline')
    assert_equal [1, 4], agent.fetch('plan').values_at('done', 'total')
  end

  private def cli(*argv)
    out, = capture_io { AgentBoard::CLI.new(argv).run }
    out
  end

  private def with_env(vars)
    saved = vars.keys.to_h { [it, ENV[it]] }
    vars.each { ENV[_1] = _2 }
    yield
  ensure
    saved.each { ENV[_1] = _2 }
  end
end
