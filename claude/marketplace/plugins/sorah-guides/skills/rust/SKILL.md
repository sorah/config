---
name: rust
description: This skill should be used when writing or reviewing Rust code, or when the project uses "Rust", "Cargo", "cargo clippy", "crate", or Rust module patterns. Provides Rust coding conventions, patterns, and best practices. Project-specific conventions always take priority.
version: 0.3.0
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

### Methods and Associated Functions

Prefer methods, associated functions, and trait impls over bare `fn`.

- Behavior that reads or mutates a type's data is a method on that type, rather than a free `fn foo(x: &Type)`
- Constructors and conversions are associated functions (`Type::new`, `Type::from_env`) or `From`/`TryFrom`/`FromStr` impls
- A helper used only by one type's methods is a private associated function in that `impl`
- Free functions fit where no type owns the operation: subcommand entry points (`cmd::<name>::run(args)`), functions a framework or attribute refers to by path (axum handlers, `#[serde(default = "...")]`), and small stateless utilities

### Adding Functionality to Other Types

For a type that cannot take an inherent `impl`, such as an external crate's struct, one or two functions using it can stay free functions. Beyond that, prefer in order:

1. A trait: a std or crate-provided one when it fits (`From`, `Display`, ...), otherwise a local extension trait (e.g., `trait ClientExt` implemented for `reqwest::Client`)
2. A wrapper struct with methods, when a trait does not fit (e.g., a `Cache` owning a `rusqlite::Connection` whose schema it manages)
3. Free functions taking the type, only when wrapping has a concrete performance cost

## Development Practices

- Must pass cargo clippy before commit
