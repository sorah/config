# Claude Code Personal Preferences

This file contains my personal preferences for Claude Code.

## General Instructions

- Follow existing code conventions and patterns in each project
- Prefer editing existing files over creating new ones
- When writing a throwaway script, prefer Ruby (except in the case human request or the project has another preference) and bundler/inline for its dependencies

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
