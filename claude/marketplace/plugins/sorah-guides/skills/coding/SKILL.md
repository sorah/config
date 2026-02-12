---
name: General Coding Guidelines
description: This skill should be used when writing or reviewing code in any language. Provides language-agnostic coding conventions for code quality, comments, error handling, and formatting. Project-specific conventions always take priority.
version: 0.1.0
---

# General Coding Guidelines

Language-agnostic coding conventions applicable across all projects. Project-specific conventions (CLAUDE.md, style guides) always take priority over this guidance.

## Code Quality

- Do not leave empty lines containing only whitespace
- Write clean, readable code that follows the language's established conventions
- Use consistent indentation and formatting

## Code Comments

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

## Error Handling

- Avoid blanket exception handling unless absolutely necessary — error logging is typically handled by the runtime or framework
- Prefer letting exceptions propagate up the call stack
- Only catch specific exceptions when there is a meaningful reason:
  - Adding context to the error
  - Performing cleanup operations
  - Converting one exception type to another with additional information
  - Recovering from expected error conditions

## Git Commit Messages

Follow these guidelines when there is no project-specific commit message convention.

### Summary Line

- Keep total length under 50 characters when possible
- Start with `{component_name}: ` prefix when possible (shortened filename or directory name; omit if it makes the line too long)
- Use imperative mood (e.g., "Add feature" not "Added feature")
- Prefer contextful verbs over generic ones like "Change", "Add", "Fix", or "Update"
- Explain the "why" of the change, not just the "what"

### Body

- Leave second line empty
- Add detailed explanation, background, or reasoning in subsequent lines
- Include relevant context that helps reviewers understand the change
