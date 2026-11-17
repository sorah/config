# frozen_string_literal: true

require_relative 'test_helper'

class IssueRefTest < Minitest::Test
  def test_branch_with_linear_key
    assert_equal 'WEB-420', AgentBoard::IssueRef.from_branch('sorah/web-420-fix-gauge').fetch('key')
  end

  def test_branch_with_unknown_team_is_ignored_when_teams_are_known
    assert_nil AgentBoard::IssueRef.from_branch('sorah/fix-12-thing', team_keys: %w[WEB])
  end

  def test_branch_with_github_issue_number
    ref = AgentBoard::IssueRef.from_branch('123-flaky-tests', repo: 'o.invalid/r')

    assert_equal 'o.invalid/r#123', ref.fetch('key')
  end

  def test_github_url_in_text
    ref = AgentBoard::IssueRef.from_text('review https://github.com/o/r/pull/77 please')

    assert_equal 'o/r#77', ref.fetch('key')
    assert_equal 'https://github.com/o/r/pull/77', ref.fetch('url')
  end

  def test_bare_key_counts_for_known_teams
    assert_equal 'OPS-61', AgentBoard::IssueRef.from_text('pick up OPS-61', team_keys: %w[OPS]).fetch('key')
  end

  def test_explicit_forms
    assert_equal 'WEB-9', AgentBoard::IssueRef.parse_explicit('web-9').fetch('key')
    assert_equal 'o/r#3', AgentBoard::IssueRef.parse_explicit('o/r#3').fetch('key')
    assert_nil AgentBoard::IssueRef.parse_explicit('nonsense')
  end
end
