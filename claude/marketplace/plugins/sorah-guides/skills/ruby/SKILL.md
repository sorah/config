---
name: ruby
description: This skill should be used when writing or reviewing Ruby code, or when the project uses "Ruby", "RSpec", "service objects", "Struct", "Data class", or Ruby class/module patterns. Provides Ruby coding conventions, patterns, and best practices. Project-specific conventions always take priority.
version: 0.2.0
---

# Ruby Conventions

Coding conventions and best practices for Ruby projects. Project-specific conventions (CLAUDE.md, style guides) always take priority over this guidance.

## File Structure

- Explicit `require` statements at top of file

## RuboCop

New projects start from sorah's baseline in [sorah/config](https://github.com/sorah/config) (checked out at `~/git/config`), copied rather than inherited, so each project owns its configuration. Leave an existing project's configuration alone.

- Copy `misc/rubocop.yml` (rubocop-shopify plus overrides) to `.rubocop.yml`, and add `rubocop-shopify` as a development dependency.
- For a Rails app, merge in `misc/rubocop.rails.yml` (the factory_bot, rails, rspec and rspec_rails plugins, with the cops it relaxes) as one `.rubocop.yml`, not as two files.
- Add an `AllCops` block:
  ```yaml
  AllCops:
    TargetRubyVersion: 3.3  # a gem's minimum supported Ruby
    SuggestExtensions: false
    Exclude:
      # protoc output, checked as generated rather than linted.
      - "lib/**/*_pb.rb"
      - "vendor/**/*"
      - ".gem_rbs_collection/**/*"
  ```
- Exclude generated code and installed signatures, each with a comment saying what it is. Never disable a cop to fit generated code.
- RuboCop runs from hk (`hk check`, `hk fix`), not directly; see the `toolchain` skill.

### Project Cops

A custom cop earns its place when the wrong code looks right at the call site and the consequence is silent (an unretried transaction, a job on a queue no worker reads, a lost audit entry) rather than a test failure.

- Keep them in one directory (e.g. `config/cops/`), listed under `require:` in `.rubocop.yml`, with a table in the project docs naming what each bans, what to use instead, and why.
- Treat an offense as a design signal. Exclude in `.rubocop.yml` only the implementation of the very thing the cop guards; elsewhere use an inline `# rubocop:disable Project/Cop -- <reason>`.

## Type Checking

- Libraries and gems: Steep with rbs-inline. See the `steep` and `steep-adoption` skills.
- Applications: Sorbet with inline RBS comments. See the `sorbet` and `sorbet-adoption` skills.

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

## Control Flow

- Prefer `case`/`when` over `if`/`elsif`. For heterogeneous conditions use a bare `case` with `when condition?` branches (`Style/CaseLikeIf` with `MinBranchesCount: 2`).
- An early return from a check that answers a value or nil reads `refusal_for(env)&.then { return it }`. It keeps the method's original last line untouched as more checks join, unlike `refusal || @app.call(env)`.
- Never interpolate into backticks or `%x()`. Run commands with `system` or `IO.popen` and an argv array.

## Data Handling

- `Hash#fetch` and `Array#fetch` for required keys/indexes
- Omit hash value when identical to key: `{foo:}` instead of `{foo: foo}`
- Consistent hash syntax with symbol keys and colons

## Error Handling

The general policy is in the `coding` skill. In Ruby:

- Never `rescue Exception`, `rescue StandardError`, or a bare `rescue` (which is `StandardError`).
- Rescue the most specific class: `Aws::S3::Errors::NoSuchKey`, not `Aws::Errors::ServiceError`.
- Raise with a descriptive message. When converting, pass `cause: e` instead of copying the cause into the message.
- Cleanup that must also run on failure re-raises with a bare `raise` (or uses `ensure`).

```ruby
# Bad - passes its own class through and copies the cause into the message
def refresh
  response = exchange
  raise RefreshError, "Response has no access_token" unless response["access_token"]

  response["access_token"]
rescue RefreshError
  raise
rescue Faraday::Error => e
  raise RefreshError, "Refresh failed: #{e.class}: #{e.message}", cause: e
end

# Good - every failure is wrapped the same way, and the details stay in the cause
def refresh
  exchange.fetch("access_token")
rescue Faraday::Error, KeyError => e
  raise RefreshError, "Refresh failed", cause: e
end
```

## Nil Handling

- Explicit nil checks vs safe navigation (`&.`) vs `fetch` with defaults
- Prefer `fetch` to surface unexpected missing keys early
- Default a missing number with `foo&.count || 0`, never `foo&.count.to_i`. `to_i` reads as a coercion of the value and hides that it exists only for nil.

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
- Enumerated payload values are Symbols (`reason: :expired`), not Strings
- Pass an exception to the logger as its own argument, never interpolated into the message (SemanticLogger: `logger.warn("Cache unavailable", {key:}, e)`)

## Scripts

- Throwaway and ad-hoc scripts are Ruby with `bundler/inline` for dependencies, unless the project or request says otherwise.

## Security

- **Credential hashing**: bcrypt or argon2 for passwords
- **Token storage**: Hashed tokens in database, plaintext never persisted
- **Constant-time comparison**: `ActiveSupport::SecurityUtils.secure_compare` or equivalent for secret comparison
