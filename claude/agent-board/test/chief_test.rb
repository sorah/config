# frozen_string_literal: true

require_relative 'test_helper'

class ChiefTest < Minitest::Test
  include AgentBoardTestHelper

  def setup
    @dir = Dir.mktmpdir
    @store = AgentBoard::Store.new(root: @dir)
  end

  def teardown
    FileUtils.remove_entry(@dir)
  end

  def test_watch_reports_new_needs_you_and_inbox_then_advances_cursor
    FileUtils.mkdir_p(@store.path('chief'))
    File.write(@store.path('chief', 'watch-cursor.json'), '{}')
    @store.update('sess-1', now: NOW) do |s|
      s.name = 'gauge-fix'
      s.ask = 'keep or drop?'
      nil
    end
    FileUtils.mkdir_p(@store.path('inbox', 'chief'))
    File.write(@store.path('inbox', 'chief', '1.json'), JSON.generate({'from' => 'rate-limiter', 'text' => 'hi'}))

    result = AgentBoard::ChiefWatch.new(store: @store).once

    assert_equal [%w[gauge-fix asking]], result.fetch('changes').map { it.values_at('agent', 'status') }
    assert_equal ['hi'], result.fetch('messages').map { it.fetch('text') }
    assert_empty Dir[@store.path('inbox', 'chief', '*.json')]
  end

  def test_start_brief_fires_once_per_workday
    @store.record_user_activity(NOW)
    watch = AgentBoard::ChiefWatch.new(store: @store)

    assert_equal 'start', watch.once.fetch('brief')
    assert_equal NOW.iso8601, @store.workday.fetch('first_activity_at')

    @store.record_user_activity(NOW + 60)

    assert_equal NOW.iso8601, @store.workday.fetch('first_activity_at')
  end

  def test_followup_brief_is_due_six_hours_after_first_activity
    @store.record_user_activity(Time.now - (6 * 3600) - 1)
    @store.mark_brief_delivered('start')

    assert_equal 'followup', AgentBoard::ChiefWatch.new(store: @store).once.fetch('brief')
  end

  def test_link_for_another_agent_is_announced_to_that_agent
    @store.update('sess-1', now: NOW) do |s|
      s.name = 'flaky-tests'
      nil
    end
    with_env('SORAH_AGENT_BOARD_HOME' => @dir) do
      capture_io { AgentBoard::CLI.new(%w[link --agent flaky-tests WEB-430]).run }
    end
    s = @store.load('sess-1')

    assert_equal 'WEB-430', s.issue.fetch('key')
    assert_equal 'chief', s.issue.fetch('source')
    assert_nil s.issue_announced
  end

  def test_relay_refuses_while_a_dialog_is_open
    session = @store.update('sess-1', now: NOW) do |s|
      s.tmux_socket = '/nonexistent.invalid'
      s.tmux_pane = '%1'
      s.blockers = [{'kind' => 'permission', 'summary' => 'Bash: rm', 'tool_use_id' => 't'}]
      nil
    end

    error = assert_raises(AgentBoard::Relay::Refused) { AgentBoard::Relay.new(store: @store).deliver(session, 'hi', from: 'chief') }
    assert_match(/dialog/, error.message)
  end

  private def with_env(vars)
    saved = vars.keys.to_h { [it, ENV[it]] }
    vars.each { ENV[_1] = _2 }
    yield
  ensure
    saved.each { ENV[_1] = _2 }
  end

  def test_first_watch_without_cursor_does_not_replay_the_whole_board
    @store.update('sess-1', now: NOW) do |s|
      s.ask = 'old question'
      nil
    end
    FileUtils.mkdir_p(@store.path('inbox', 'chief'))
    File.write(@store.path('inbox', 'chief', '1.json'), JSON.generate({'from' => 'user', 'text' => 'wake'}))

    result = AgentBoard::ChiefWatch.new(store: @store).once

    assert_empty result.fetch('changes')
  end
end
