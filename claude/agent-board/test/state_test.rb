# frozen_string_literal: true

require_relative 'test_helper'

class StateTest < Minitest::Test
  include AgentBoardTestHelper

  def test_prompt_starts_a_turn_and_records_the_goal
    s = new_session
    apply(s, 'UserPromptSubmit', prompt: "Fix the pressure gauge\nmore detail")

    assert_equal :working, s.status
    assert_equal 'Fix the pressure gauge', s.goal
  end

  def test_stop_marks_done_unseen_and_records_the_turn_summary
    s = new_session
    apply(s, 'UserPromptSubmit', prompt: 'go')
    events = apply(s, 'Stop', last_assistant_message: 'Reproduced the bug; writing the test next.')

    assert_equal :done, s.status
    assert_equal 'Reproduced the bug; writing the test next.', s.last_report.fetch('text')
    assert_equal ['summary'], events.map { it.fetch('kind') }
  end

  def test_permission_request_blocks_until_that_tool_finishes
    s = new_session
    input = {'command' => 'sudo true'}
    apply(s, 'PreToolUse', tool_name: 'Bash', tool_input: input, tool_use_id: 'tu-1')
    apply(s, 'PermissionRequest', tool_name: 'Bash', tool_input: input)

    assert_equal :blocked, s.status
    assert_equal 'tu-1', s.blockers.first.fetch('tool_use_id')

    apply(s, 'PostToolUse', tool_name: 'Bash', tool_input: input, tool_use_id: 'tu-1', tool_response: {})

    assert_equal :working, s.status
  end

  def test_parallel_tool_completion_does_not_clear_another_tools_permission_block
    s = new_session
    apply(s, 'PreToolUse', tool_name: 'Bash', tool_input: {'command' => 'ls'}, tool_use_id: 'tu-1')
    apply(s, 'PreToolUse', tool_name: 'Bash', tool_input: {'command' => 'sudo true'}, tool_use_id: 'tu-2')
    apply(s, 'PermissionRequest', tool_name: 'Bash', tool_input: {'command' => 'sudo true'})
    apply(s, 'PostToolUse', tool_name: 'Bash', tool_input: {'command' => 'ls'}, tool_use_id: 'tu-1', tool_response: {})

    assert_equal :blocked, s.status
  end

  def test_ask_user_question_blocks_until_answered
    s = new_session
    input = {'questions' => [{'question' => 'Dec 1 or Jan 15?'}]}
    apply(s, 'PreToolUse', tool_name: 'AskUserQuestion', tool_input: input, tool_use_id: 'tu-q')

    assert_equal :blocked, s.status
    assert_equal 'Dec 1 or Jan 15?', s.blockers.first.fetch('summary')

    apply(s, 'PostToolUse', tool_name: 'AskUserQuestion', tool_input: input, tool_use_id: 'tu-q', tool_response: {})

    assert_equal :working, s.status
  end

  def test_idle_prompt_notification_ends_a_turn_interrupted_without_stop
    s = new_session
    apply(s, 'UserPromptSubmit', prompt: 'go')
    apply(s, 'Notification', notification_type: 'idle_prompt', message: 'waiting')

    refute s.turn_active
  end

  def test_stop_failure_shows_an_error_until_the_next_prompt
    s = new_session
    apply(s, 'UserPromptSubmit', prompt: 'go')
    apply(s, 'StopFailure', error: 'rate_limit')

    assert_equal :error, s.status

    apply(s, 'UserPromptSubmit', prompt: 'retry')

    assert_equal :working, s.status
  end

  def test_session_end_parks_and_keeps_everything
    s = new_session
    apply(s, 'UserPromptSubmit', prompt: 'half-done work')
    apply(s, 'SessionEnd', reason: 'exit')

    assert_equal :parked, s.status
    assert_equal 'half-done work', s.goal

    apply(s, 'SessionStart', source: 'resume')

    refute_equal :parked, s.status
  end

  def test_git_commit_becomes_a_milestone
    s = new_session
    events = apply(s, 'PostToolUse', tool_name: 'Bash', tool_input: {'command' => 'git commit -m x'}, tool_use_id: 't', tool_response: {})

    assert_equal [['commit', 'Fix the gauge']], events.map { [it.fetch('kind'), it.fetch('text')] }
  end

  def test_failed_test_run_is_recorded_as_failed
    s = new_session
    events = apply(s, 'PostToolUseFailure', tool_name: 'Bash', tool_input: {'command' => 'bundle exec rspec'}, tool_use_id: 't', error: 'Exit code 1')

    assert_match(/rspec failed \(Exit code 1\)/, events.first.fetch('text'))
  end

  def test_pr_create_records_url_and_links_nothing_when_already_linked
    s = new_session
    s.issue = {'key' => 'WEB-1'}
    apply(s, 'PostToolUse', tool_name: 'Bash', tool_input: {'command' => 'gh pr create --fill'}, tool_use_id: 't',
                            tool_response: {'stdout' => "https://github.com/o.invalid/r/pull/12\n"})

    assert_equal 'https://github.com/o.invalid/r/pull/12', s.pr_url
    assert_equal 'WEB-1', s.issue.fetch('key')
  end

  def test_prompt_links_linear_url_but_not_unknown_bare_keys
    s = new_session
    apply(s, 'UserPromptSubmit', prompt: 'convert UTF-8 handling')

    assert_nil s.issue

    s = new_session
    apply(s, 'UserPromptSubmit', prompt: 'see https://linear.app/acme/issue/WEB-420/fix-it')

    assert_equal 'WEB-420', s.issue.fetch('key')
  end

  def test_status_since_changes_only_when_status_changes
    s = new_session
    apply(s, 'UserPromptSubmit', prompt: 'go')
    since = s.status_since
    apply(s, 'PreToolUse', now: NOW + 60, tool_name: 'Read', tool_input: {}, tool_use_id: 't')

    assert_equal since, s.status_since
  end

  def test_only_the_first_prompt_links_an_issue
    s = new_session
    apply(s, 'UserPromptSubmit', prompt: 'refactor the parser')
    apply(s, 'UserPromptSubmit', prompt: 'log says https://github.com/o/r/pull/9')

    assert_nil s.issue
  end

  def test_subagent_commands_do_not_produce_milestones
    s = new_session
    events = apply(s, 'PostToolUse', tool_name: 'Bash', tool_input: {'command' => 'git commit -m x'}, tool_use_id: 't',
                                     tool_response: {}, agent_id: 'sub-1')

    assert_empty events
  end
end
