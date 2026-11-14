---
name: rails
description: This skill should be used when writing or reviewing Ruby on Rails code, or when the project uses "Rails", "ActiveRecord", "ActiveJob", "ActionMailer", "concerns", "migrations", "initializers", "Rails.configuration", "before_action", "request specs", "let_it_be", or "controller". Provides Rails coding conventions for configuration, models, controllers, jobs, mailers, logging, API changes and testing. Project-specific conventions always take priority.
version: 0.2.0
---

# Rails Conventions

Coding conventions and best practices for Ruby on Rails projects. Project-specific conventions (CLAUDE.md, style guides) always take priority over this guidance.

Related skills:

- API error responses (RFC 9457 problem details with the `problem` gem): /sorah-guides:rails-problem
- Protobuf-native APIs (Connect RPC with connect_rpc_rails, protobufable, protovalidate): /sorah-guides:rails-protobuf
- Declarative schema with psqldef instead of migrations: /sorah-guides:sqldef-on-rails
- Aurora DSQL (OCC-aware transactions, IAM auth, tests against real clusters): /sorah-guides:dsql-on-rails
- Running on AWS Lambda (function URL behind CloudFront, Lambdakiq jobs, runner for migrations): /sorah-guides:rails-on-lambda
- Canonical log lines (request context, outcome and counters on the rails_semantic_logger Completed line): /sorah-guides:rails-canonical-log-line
- Sorbet typing: /sorah-guides:sorbet

## Configuration

- **One initializer per subsystem**: Settings for a subsystem (mailer, jobs, sessions, an API client) live in `config/initializers/<feature>.rb`, branching on `Rails.env` inside it, so the whole story reads top to bottom in one file. Do not add settings to `config/application.rb` or `config/environments/*.rb`; leave those with the boilerplate Rails generated (eager_load, caching, logging level) and settings that must exist before initializers run (`load_defaults`, autoload paths, logger setup such as `config.rails_semantic_logger`).
- **Namespaced settings**: `Rails.configuration.x.namespace.key`, two levels deep. A single-level `config.x.foo` is not allowed.
- **No explicit `OrderedOptions`**: `config.x.mailer.subject_prefix = "..."` creates the `mailer` namespace on first access. Assigning `config.x.mailer = ActiveSupport::OrderedOptions.new` first is noise, and clobbers anything set earlier.
- **ENV and `Rails.env` stay in config**: Initializers read `ENV.fetch` and branch on `Rails.env`. Application code (models, controllers, jobs, services) reads `Rails.configuration.x` and never checks `ENV` or `Rails.env`; environment differences are configuration values.
- **Rake task arguments**: A rake task may read its own per-invocation inputs (`ENV["VERBOSE"]`, `ENV["KEY_ID"]`) inside the task body and pass them down as arguments. A setting that varies per deployment still goes through `config.x`, even when only a task uses it.

```ruby
# config/initializers/mailer.rb
Rails.application.configure do
  case
  when Rails.env.development?
    config.action_mailer.delivery_method = :letter_opener_web
  when Rails.env.test?
    config.action_mailer.delivery_method = :test
  else
    config.action_mailer.delivery_method = :ses_v2
  end

  config.x.mailer.subject_env_prefix = ENV.fetch("MAILER_SUBJECT_ENV_PREFIX") do
    Rails.env.production? ? "" : "[#{Rails.env.upcase}] "
  end
end

# Application code
prefix = Rails.configuration.x.mailer.subject_env_prefix
```

## Data Model — ActiveRecord

- **Migrations**: Specify column types, defaults, null constraints, and index definitions explicitly
- **Index correctness**: Unique vs non-unique; composite index column order matching query patterns
- **Validations on the model**: A rule about the data itself (range, format, presence, cross-column consistency, lifetime bounds) is an AR `validates`/`validate` on the model, so every writer (job, rake task, console, factory) hits it. Controllers check only what the model cannot see: authentication, authorization, request shape. `RecordInvalid` from `save!` renders as a problem (see /sorah-guides:rails-problem).
- **Database constraints** back the validations that must hold under concurrency (uniqueness, foreign keys, not-null).
- **Associations**: `has_many`, `belongs_to`, `has_one` — specify dependent behavior and foreign key constraints
- **Model concerns**: Custom `ActiveModel::Type` classes and other AR-adjacent modules reused across models live in `app/models/concerns/`, not at the root of `app/models/` or in a new `app/types/`.

## Architecture & Design

- **Where logic lives**: Model callbacks vs service objects vs controller-level orchestration — prefer service objects for complex business logic
- **Concerns**: Extract shared behavior as model or controller concerns, each named for what it does. A gate that is not authentication goes in its own concern rather than growing the authentication one.
- **Errors**: Models and services raise problem classes named for the failure, and controllers let them propagate; no rescue-and-rewrap into status-named errors, no per-class `rescue_from` (see /sorah-guides:rails-problem)

## Controllers

- **DSL at the top**: `include`, `before_action`, `skip_before_action`, `rescue_from` and other class macros open the class body, before any action.
- **Thin actions**: Strong parameters (or a declared protobuf message, see /sorah-guides:rails-protobuf); orchestration in a service or model.
- **Cross-cutting hooks are `before_action`**: A concern registers its check with `before_action` in `included`; a controller opts out with `skip_before_action :name, raise: false`. Do not hide a request hook in a lazy accessor or a `send_action`/`process_action` override.
- **Authentication answers first**: A missing credential is a 401 before a malformed body is a 400. A hook included into the base controller runs before a subclass's authentication callback; when that order matters, re-append the hook from the concern instead of relying on include order.

## Jobs and Mailers

- `enqueue_after_transaction_commit` is on for every job, `MailDeliveryJob` included (set it in the jobs initializer, not only on `ApplicationJob`), so a worker never sees rows that are not committed. Never opt out per job; a spec that loses an enqueued job is holding the transaction open (see Testing).
- Pass record IDs, not objects, and re-fetch in `perform`. Jobs are retried, so make them idempotent by checking state before mutating.
- Request-scoped context (`CurrentAttributes`) that a job needs is serialized at enqueue and restored around `perform` by a concern on `ApplicationJob`, never passed by hand.
- Mailers inherit `ApplicationMailer`, compose inside the context they need, and send with `deliver_later`. Non-production deployments gate recipients with an interceptor.

Patterns and pitfalls (context propagation, `MailDeliveryJob`, interceptor registration under reloading, common job kinds): `references/jobs-and-mailers.md`.

## Logging

- Structured logging with rails_semantic_logger: `logger.info("Message", key: value)`. Pass an exception as its own argument (`logger.error("Message", {order_id:}, e)`), never interpolated into the message.
- A gate that refuses requests logs the refusal with `logger.warn` and a payload naming the reason. That is enough; add a metric only when someone will watch it.
- Code that rescues and does not re-raise (recovering, or wrapping at a boundary) logs the exception; when recovering, also `Sentry.capture_exception(e, level: :warning)`. Errors that propagate are reported by the framework.
- One canonical line per request (see /sorah-guides:rails-canonical-log-line).

API details (signatures, `measure_*`, level checks): `references/logging.md`.

## API Changes

A behaviour change on an existing endpoint that a client could notice ships opt-in first, through a preview media type in `Accept` (GitHub's REST API previews model): `Accept: application/json, application/vnd.<app>.<name>-preview+json`.

- A controller concern declares the previews and answers `api_preview?(:name)`; register each media type with `Mime::Type.register` in an initializer. Responses keep their usual `Content-Type`.
- Branch on `api_preview?` exactly where behaviour differs. Keep the current path under a `TODO:` naming the preview that replaces it, and cover both paths in request specs.
- Graduating removes the branch and the superseded path; keep accepting the media type as a no-op for at least one release.
- Document each active preview (name, media type, what changes, endpoints) in the API docs.

## Integration

- **Encryption**: ActiveRecord Encryption or application-level keyring for sensitive attributes
- **Existing concerns**: Identify which existing model or controller concerns new code should include

## Testing

Prefer test-driven development: write a failing test first (Red), implement minimum code to pass (Green), then refactor while keeping tests green. Tests should cover both happy paths and error conditions.

- **Request specs**: HTTP-level specs for API endpoints; verify status codes, response bodies, error formats. When the API has an OpenAPI document, validate request and response with openapi_first's `assert_api_conform(status:)`.
- **Model specs**: Validation, association, and scope coverage
- **Integration tests**: Real database interactions — do not mock ActiveRecord
- **Test data**: FactoryBot. `let_it_be` (test-prof) only for records no example mutates.
- **`build` over `create`**: Use `FactoryBot.build` unless the example needs a persisted record (scopes, queries, uniqueness constraints). In-memory behavior and delegation (`build` plus a mock) need no write.
- **Post-commit side effects**: A spec that wraps each example in a transaction defers `after_commit` callbacks and `enqueue_after_transaction_commit` until the wrapper commits. Run examples asserting those outside the wrapper; never change the production code to make them pass.
- **No query-count assertions**: Profile statement counts ad hoc (e.g. a `sql.active_record` subscriber, test-prof `EVENT_PROF`), quote the numbers in the PR, and keep only behavioral specs. A count encodes the current implementation and breaks on unrelated refactors.
- **No wall-clock assertions**: Never assert timing parity or speed by measuring elapsed time; it flakes under CI jitter. Assert the mechanism instead, e.g. both paths call the same primitive the same number of times.
- **Cleanup is global**: Whatever cleans the database between examples (transactional fixtures, database_rewinder) is configured once in `spec/support/`; spec files add no `after { Model.delete_all }`.
- **Time-dependent tests**: Timecop or `travel_to` depending on project convention, block form so time is restored

Examples and tooling (`let_it_be` pitfalls, openapi_first setup, profiling commands): `references/testing.md`.

## Security

- **Password hashing**: `has_secure_password` or dedicated service
- **Parameter filtering**: `filter_parameters` configuration for sensitive request params
- **Audit logging**: Identify which actions require audit trail entries

## Operations

- **`bin/setup`**: Seed data, fixture files for development
- **Rake tasks**: Data migrations, cleanup jobs, one-off operations
- **Key rotation**: Keyring rotation strategy for encrypted attributes

## Additional Resources

- **`references/jobs-and-mailers.md`** - ActiveJob and ActionMailer patterns: context propagation, mail delivery job, interceptors, job kinds
- **`references/logging.md`** - SemanticLogger API and Sentry reporting
- **`references/testing.md`** - `let_it_be`, OpenAPI contract tests, build vs create, profiling
