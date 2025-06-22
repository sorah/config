# Claude Code Personal Preferences

This file contains my personal preferences for Claude Code.

## General Instructions

- Always ensure files end with a newline character (`\n`)
- Follow existing code conventions and patterns in each project
- Prefer editing existing files over creating new ones

## Code Quality Standards

- Throw errors instead of silently ignoring them (unless explicitly instructed otherwise)
- Do not leave empty lines containing only whitespace
- Write clean, readable code that follows language conventions
- Use consistent indentation and formatting

## Language-Specific Style Guides

**CRITICAL REQUIREMENT**: Before writing or modifying ANY code in the following languages, you MUST first read and apply the corresponding style guide. This is non-negotiable.

**Mandatory Process:**
1. **Always read the style guide file first** using the Read tool
2. **Apply all conventions** from the style guide to your code
3. **Reference specific style guide rules** when making decisions

**Style Guide Files:**
- Ruby: @~/git/config/claude/ruby.md
- Terraform: @~/git/config/claude/terraform.md

**Enforcement**: If you write code without following these style guides, the code will be considered incorrect and must be rewritten.

## Git Commit Message Format

### First Line (Summary)
- Try to keep total length under 50 characters
- Start with `{component_name}: ` prefix when possible
  - Component name can be shortened filename or directory name
  - Omit prefix if it would make the line too long
- Use imperative mood (e.g., "Add feature" not "Added feature")
- Use more contextful verbs than "Change", "Add", "Fix" or "Update"
- Try to explain the "why" of the change, not just the "what"

### Additional Lines
- Leave second line empty
- Add detailed explanation, background, or reasoning in subsequent lines
- Include relevant context that helps reviewers understand the change

## File Management

- Never create files unless absolutely necessary
- Always prefer editing existing files to creating new ones
- Do not proactively create documentation files (*.md, README) unless explicitly requested
- When working with a temporary file or temporary output, create them in `tmp/` directory under the repository root. No need to delete.
