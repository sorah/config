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

- **Ruby Conventions** /sorah-guides:ruby — e.g. data handling, AWS SDK, testing
- **Terraform Conventions** /sorah-guides:terraform — e.g. file organization, naming, AWS-specific patterns
- **Git Commit Style** /sorah-guides:commit-style — e.g. subject lines, prefix patterns, contextful verbs

### General Coding Guidelines

This section mirrors the **/sorah-guides:coding** skill; keep them in sync.

Language-agnostic coding conventions applicable across all projects. Project-specific conventions (CLAUDE.md, style guides) always take priority over this guidance.

#### Code Quality

- Do not leave empty lines containing only whitespace
- Write clean, readable code that follows the language's established conventions
- Use consistent indentation and formatting

#### Code Comments

Comments must not repeat what the code already expresses. Use comments for explaining **why** something is done, or to provide context not obvious from the code itself.

**When to comment:**

- To explain why a particular approach or workaround was chosen
- To clarify intent when the code could be misread or misunderstood
- To provide context from external systems, specs, or requirements
- To document assumptions, edge cases, or limitations

**When not to comment:**

- Do not narrate what the code is doing — the code already says that
- Do not duplicate function or variable names in plain English
- Do not leave stale comments that contradict the code
- Do not reference removed or obsolete code paths

#### Error Handling

- Avoid blanket exception handling unless absolutely necessary — error logging is typically handled by the runtime or framework
- Prefer letting exceptions propagate up the call stack
- Only catch specific exceptions when there is a meaningful reason:
  - Adding context to the error
  - Performing cleanup operations
  - Converting one exception type to another with additional information
  - Recovering from expected error conditions

## File Management

- Never create files unless absolutely necessary
- Always prefer editing existing files to creating new ones
- Do not proactively create documentation files (*.md, README) unless explicitly requested
- When working with a temporary file, temporary script, or temporary output, create them in `tmp/` directory under the repository root. No need to delete.
  - Human usually declines using `/tmp` directory, outside of the project directory.

## Git GPG Signing

- When encountered git commit error due to 'gpg: signing failed: Inappropriate ioctl for device', ask human to unlock their signing key instead of skipping signature.
