# Claude Code Personal Preferences

This file contains my personal preferences for Claude Code.

## General Instructions

- Follow existing code conventions and patterns in each project
- Prefer editing existing files over creating new ones
- When writing a throwaway script, prefer Ruby (except in the case human request or the project has another preference) and bundler/inline for its dependencies

### Git

- Before any commit/branch/push, verify the live branch with `git branch --show-current` (never the session-start snapshot) and commit onto the currently checked-out branch. Never blindly create a branch; if it's the default branch, stop and ask first.
- Commit or push only when the user asks.
- Each commits should be self-contained, i.e. include schema and implementation changes together.
  - During the plan, group tasks by commits.
- Interactive flags (`-i`, e.g. `git rebase -i`, `git add -i`) are not supported in this environment.
- Use the `gh` CLI for GitHub operations (PRs, issues, API).

## Required Plugins

This file references skills from the **sorah-guides** and **sorah-spec** plugins. If either plugin is not loaded (i.e. their skills do not appear in the available skills list), warn the user immediately at the start of the conversation.

## Coding & Style Guides

Follow the **sorah-guides** plugin skills for coding conventions:

- **General Coding Guidelines** skill (sorah-guides:coding) — e.g. code quality, comments, error handling
- **Ruby Conventions** skill (sorah-guides:ruby) — e.g. data handling, AWS SDK, testing
- **Terraform Conventions** skill (sorah-guides:terraform) — e.g. file organization, naming, AWS-specific patterns
- **Git Commit Style** skill (sorah-guides:commit-style) — e.g. subject lines, prefix patterns, contextful verbs

## File Management

- Never create files unless absolutely necessary
- Always prefer editing existing files to creating new ones
- Do not proactively create documentation files (*.md, README) unless explicitly requested
- When working with a temporary file, temporary script, or temporary output, create them in `tmp/` directory under the repository root. No need to delete.
  - Human usually declines using `/tmp` directory, outside of the project directory.

## Git GPG Signing

- When encountered git commit error due to 'gpg: signing failed: Inappropriate ioctl for device', ask human to unlock their signing key instead of skipping signature.
