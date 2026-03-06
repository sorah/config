---
name: rust
description: This skill should be used when writing or reviewing Rust code, or when the project uses "Rust", "Cargo", "cargo clippy", "crate", or Rust module patterns. Provides Rust coding conventions, patterns, and best practices. Project-specific conventions always take priority.
version: 0.2.0
---

# Rust Conventions

Coding conventions and best practices for Rust projects. Project-specific conventions (CLAUDE.md, style guides) always take priority over this guidance.

## Coding Guidelines

### Import (`use`) Statements

__Default: Don't use `use` unless explicitly requested by humans__

- Global `use` statements at the top of files are discouraged (except in `mod.rs` and `lib.rs`)
- Avoid `use` for structs and enums - ALWAYS prefer full paths (e.g., `std::collections::HashMap` instead of `use std::collections::HashMap`)
- `use` is allowed for frequently used modules within the same crate (e.g., `use crate::error::Error`)
- When importing traits, place the `use` statement in the most specific scope where they're needed

### Using `crate::` reference

- Always use `crate::` for referencing items within the same crate, even in the same module (e.g., `crate::utils::helper_function()`)

## Development Practices

- Must pass cargo clippy before commit
