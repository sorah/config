---
name: Ruby Conventions
description: This skill should be used when writing or reviewing Ruby code, or when the project uses "Ruby", "RSpec", "service objects", "Struct", "Data class", or Ruby class/module patterns. Provides Ruby coding conventions, patterns, and best practices. Project-specific conventions always take priority.
version: 0.1.0
---

# Ruby Conventions

Coding conventions and best practices for Ruby projects. Project-specific conventions (CLAUDE.md, style guides) always take priority over this guidance.

## File Structure

- Explicit `require` statements at top of file

## Naming

- Class names in PascalCase, method names in snake_case
- File paths matching class hierarchy (e.g., `lib/my_app/user_service.rb` for `MyApp::UserService`)
- Constants in `SCREAMING_SNAKE_CASE`

## Architecture & Design

- **Service objects**: Command/service pattern for encapsulating business logic outside models
- **Module structure**: Namespace hierarchy; `include` for instance behavior, `extend` for class behavior
- **Data structures**: Struct or Data classes for value objects instead of raw hashes

## Methods

- Keyword arguments for methods with multiple parameters
- `def self.method_name` for class methods
- Guard clauses for early returns on precondition checks
- `attr_reader` over direct instance variable access
- Short single-line methods when appropriate

## Data Handling

- `Hash#fetch` and `Array#fetch` for required keys/indexes
- Omit hash value when identical to key: `{foo:}` instead of `{foo: foo}`
- Consistent hash syntax with symbol keys and colons

## Error Handling

- Rescue specific exceptions only (e.g., `Aws::S3::Errors::NoSuchKey`), never `rescue Exception` or bare `rescue`
- Raise with descriptive messages
- Let exceptions propagate unless there is a meaningful reason to catch them:
  - Adding context to the error
  - Performing cleanup operations
  - Converting one exception type to another
  - Recovering from expected error conditions

## Nil Handling

- Explicit nil checks vs safe navigation (`&.`) vs `fetch` with defaults
- Prefer `fetch` to surface unexpected missing keys early

## Testing — RSpec

- Describe/context/it hierarchy; spec file placement mirroring source tree
- Factory patterns for test data; understand `let` (lazy) vs `let!` (eager) semantics
- Cover error paths and edge cases: nil inputs, empty collections, boundary values
- Spec examples for each documented error condition

## AWS SDK

- Lazy initialize AWS clients as instance variables
- Pass logger to AWS clients
- Use symbolized keys for AWS responses
- In AWS Lambda contexts, initialize with dependency injection via `environment:` parameter

## Logging

- Use structured logging with JSON when appropriate
- Log important operations (locks, state changes)

## Security

- **Credential hashing**: bcrypt or argon2 for passwords
- **Token storage**: Hashed tokens in database, plaintext never persisted
- **Constant-time comparison**: `ActiveSupport::SecurityUtils.secure_compare` or equivalent for secret comparison
