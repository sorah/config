---
name: rails
description: This skill should be used when writing or reviewing Ruby on Rails code, or when the project uses "Rails", "ActiveRecord", "ActiveJob", "concerns", "migrations", "Rails.configuration", "request specs", or "controller". Provides Rails coding conventions, patterns, and best practices. Project-specific conventions always take priority.
version: 0.1.0
---

# Rails Conventions

Coding conventions and best practices for Ruby on Rails projects. Project-specific conventions (CLAUDE.md, style guides) always take priority over this guidance.

## Data Model — ActiveRecord

- **Migrations**: Specify column types, defaults, null constraints, and index definitions explicitly
- **Index correctness**: Unique vs non-unique; composite index column order matching query patterns
- **Validations**: Decide which layer enforces what — model-level validations vs database constraints
- **Associations**: `has_many`, `belongs_to`, `has_one` — specify dependent behavior and foreign key constraints

## Architecture & Design

- **Concerns**: Extract shared behaviors as ActiveRecord or ActionController concerns
- **Where logic lives**: Model callbacks vs service objects vs controller-level orchestration — prefer service objects for complex business logic
- **Controller design**: Keep actions thin; use before_action filters and strong parameters

## Configuration

- **Namespaced settings**: Use `Rails.configuration.x.namespace.key` with second-level namespacing; avoid single-level `Rails.configuration.x.foo`
- **Centralize ENV access**: Define configuration in `config/environments/*.rb` using `ENV.fetch`; avoid direct `ENV` access in application code
- **Avoid `Rails.env` checks**: Do not use `Rails.env.production?` or similar in application code; express environment differences through configuration values instead

```ruby
# Good — config/environments/production.rb
Rails.configuration.x.oauth.client_id = ENV.fetch("OAUTH_CLIENT_ID")
Rails.configuration.x.session.idle_timeout = 30.minutes

# Good — application code
client_id = Rails.configuration.x.oauth.client_id

# Bad — direct ENV access in application code
client_id = ENV.fetch("OAUTH_CLIENT_ID")

# Bad — Rails.env check in application code
if Rails.env.production?
```

## Integration

- **Encryption**: ActiveRecord Encryption or application-level keyring for sensitive attributes
- **Background jobs**: ActiveJob / Sidekiq job classes, queue names, retry policies
- **Logging**: Structured logging patterns (SemanticLogger or Rails.logger with payload hashes)
- **Existing concerns**: Identify which existing model or controller concerns new code should include
- **Mailers**: ActionMailer classes, delivery method (inline vs background)

## Testing

Prefer test-driven development: write a failing test first (Red), implement minimum code to pass (Green), then refactor while keeping tests green. Tests should cover both happy paths and error conditions.

- **Request specs**: HTTP-level specs for API endpoints; verify status codes, response bodies, error formats
- **Model specs**: Validation, association, and scope coverage
- **Integration tests**: Real database interactions — do not mock ActiveRecord
- **Test data**: FactoryBot patterns; `let_it_be` for read-only fixtures shared across examples
- **Test domains**: Use `.invalid` TLD for fake hostnames and URLs in test data (RFC 2606 reserved, guaranteed to never resolve)
- **Time-dependent tests**: Timecop or `travel_to` depending on project convention

## Security

- **Password hashing**: `has_secure_password` or dedicated service
- **Parameter filtering**: `filter_parameters` configuration for sensitive request params
- **Audit logging**: Identify which actions require audit trail entries

## Operations

- **`bin/setup`**: Seed data, fixture files for development
- **Rake tasks**: Data migrations, cleanup jobs, one-off operations
- **Key rotation**: Keyring rotation strategy for encrypted attributes
