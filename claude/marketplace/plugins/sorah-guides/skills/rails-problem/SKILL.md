---
name: rails-problem
description: This skill should be used when designing, writing, or reviewing error handling in a Rails API that answers RFC 9457 / RFC 7807 problem details through the `problem` gem, or when adding an error class, a `rescue_from`, an exceptions app, or an error response shape to a Rails API. Signs include `Problem::Detailable`, `Problem::Rescuable`, `Problem::I18nable`, `Problem::ExceptionsApp`, `config.problem.type_prefix`, `application/problem+json`, an `Errors::ApiError` base class, or the user mentioning "problem details", "problem+json", "error catalogue", or "error response format". Provides the error class layout, rescuing, exceptions app, i18n titles, reporting, and machine-readable detail. Project-specific conventions always take priority.
version: 0.1.0
---

# Rails API Errors with `problem`

Conventions for answering errors from a Rails API as [RFC 9457](https://www.rfc-editor.org/rfc/rfc9457.html) problem documents with the [`problem`](https://github.com/sorah/problem) gem. Project-specific conventions (CLAUDE.md, `docs/`) always take priority.

`problem` works on its own: error classes declare `type`, `status` and `title` with its DSL, and nothing else is needed. An app whose schema lives in `.proto` files can instead take those from a protobuf enum through protobufable; the sections below cover both, and /sorah-guides:rails-protobuf covers the enum catalogue and answering problems over Connect RPC. Application examples come from [ruby-no-kai/sponsor-app](https://github.com/ruby-no-kai/sponsor-app), which uses the protobuf form.

## The model

An error is a class. Its `type`, `status` and `title` belong to the class and are declared once; only `detail` (and machine-readable extras) vary per occurrence. A controller concern renders every such class, and an exceptions app renders whatever escapes before a controller runs, so every failure a client sees has one shape.

- Clients dispatch on `type`. A title can be reworded freely; a `type` is a published identifier and is append-only.
- The status is a property of the problem type, not of the code path that raised it. Two failures needing different statuses are two types.
- `detail` is prose for a person, specific to the occurrence. Anything a client acts on goes in an extension member, never parsed out of `detail`.

## Error classes

One base class carries the mixin; every error is a subclass that declares what differs. Keep them together in `app/models/errors.rb` (a module `Errors`), with a one-line doc comment per class saying when it is raised.

### Plain declarations

Without protobuf, the base includes `Problem::Detailable` (or `Problem::I18nable` for translated titles, which brings `Detailable` with it), and each class declares its members with the DSL:

```ruby
# app/models/errors.rb
module Errors
  # An error the API answers as a problem.
  class ApiError < StandardError
    include Problem::Detailable
  end

  # The resource the request names does not exist.
  class NotFound < ApiError
    type "not-found"
    status 404
    title "Not Found"
  end

  # The resource is not in a state that allows the request.
  class FailedPrecondition < ApiError
    type "failed-precondition"
    status 412
    title "Failed Precondition"
  end
end
```

- `type` is a slug resolved against `config.problem.type_prefix`; without a `type` the document says `about:blank`.
- A subclass inherits every declaration and overrides only what differs: `class Orders::AlreadyShipped < Errors::FailedPrecondition` with its own `type` and `title` keeps the 412.
- A class that declares a literal `title` keeps it even under `Problem::I18nable`, so titles can move to locale files gradually.

### From a protobuf enum

With protobufable, the base includes `Protobufable::Problem::Typeable` and points at an enum whose values carry the `uri` and `http_status`; each class names a value instead of declaring members. sponsor-app:

```ruby
# app/models/errors.rb (sponsor-app)
module Errors
  # An error the API answers as a problem, typed by a value of the ProblemType enum in
  # proto/rubykaigi/sponsor_app/problem.proto.
  class ApiError < StandardError
    include Protobufable::Problem::Typeable

    #: () -> String
    def self.problem_type_enum = 'rubykaigi.sponsor_app.ProblemType'

    #: () -> String
    def self.problem_type_annotation = 'rubykaigi.sponsor_app.problem_type'
  end

  # The resource the request names does not exist.
  class NotFound < ApiError
    problem_type :PROBLEM_TYPE_NOT_FOUND
  end
end
```

`Typeable` includes `Problem::I18nable`, and so `Problem::Detailable`, so everything below (rendering, hooks, the exceptions app, extension members) applies unchanged. Titles come from locale files, keyed by the `uri`.

### Either way

- Raise with a `detail:` that names the specific thing: `raise Errors::NotFound.new(detail: "No conference has the slug #{slug.inspect}.")`. Never put internals (SQL, stack details, other tenants' data) in `detail`; it goes to the client.
- Declare a new class rather than raising a generic one with a special `detail`. A subclass that declares nothing renders exactly as its parent, which is the tool for hiding a distinction: when a caller must not tell two failures apart, make an empty subclass instead of a new `type`.
- Keep the set small and general (unauthenticated, permission-denied, not-found, conflict, failed-precondition, invalid-record, internal). Add a specific type only when a client will branch on it.

## Rendering

Include `Problem::Rescuable` once in the API's base controller. It rescues every class that mixed in `Problem::Detailable`, so do not add a `rescue_from` per error class; make the error class detailable instead.

Convert framework exceptions into problems at one place in the base controller, and render them with `render_problem_detailable`. sponsor-app turns `ActiveRecord::RecordInvalid` from `save!` into its own `InvalidRecord` problem:

```ruby
rescue_from ActiveRecord::RecordInvalid, with: :render_invalid_record

private def render_invalid_record(error)
  # ...
  render_problem_detailable(Errors::InvalidRecord.new(record: error.record, ...))
end
```

Actions then call `save!`/`update!` and let validation failures propagate, instead of branching on `save` and rendering errors by hand.

Hooks on a controller including `Problem::Rescuable`, overridden as `private def`:

| hook | use for |
|---|---|
| `problem_for(error)` | Adding request-derived members, such as `instance` |
| `around_problem_render(&)` | Re-establishing the locale (or other per-request state) while rendering |
| `report_problem?(error, problem)` | What counts as reportable (default: status >= 500) |
| `report_problem(error, problem)` | Where reports go |
| `render_problem(problem, error)` | Answering in another shape entirely |

sponsor-app reports every problem to Sentry, as `rescue_from` swallows it before Sentry's middleware sees it:

```ruby
# rescue_from swallows the problem before Sentry's middleware sees it, and Sentry does not
# subscribe to the Rails error reporter here.
private def report_problem(error, problem)
  super
  Sentry.capture_exception(error)
end
```

## Configuration and the exceptions app

Configure in `config/initializers/problem.rb`:

```ruby
Rails.application.configure do
  # Problem types are identifiers rather than links, so every environment publishes the production
  # host's.
  config.problem.type_prefix = 'https://sponsorships.rubykaigi.org/problems/'
  config.exceptions_app = Problem::ExceptionsApp.new(ActionDispatch::PublicExceptions.new(Rails.public_path))
end
```

- `type_prefix` is the same in every environment. A `type` is an identifier, not a link that must resolve per host.
- `Problem::ExceptionsApp` answers routing errors, unreadable bodies and middleware failures as problems with the status text instead of the exception message, while browsers keep the static error pages. Subclass it when escaped errors need another shape, as sponsor-app's `ConnectExceptions` does for Connect clients.
- Request specs that exercise the exceptions app need `action_dispatch.show_exceptions = :all` around the example; sponsor-app tags them `:escaping_exceptions` (`spec/support/connect_helper.rb`).

## Localized titles

`title` is the only member written for a human, so it is the one to translate. Include `Problem::I18nable` in the base class; titles are keyed by `type` with dashes replaced, under `problem_details.titles` in `config/locales/*.yml`. Wrap rendering in the request's locale:

```ruby
private def around_problem_render(&) = I18n.with_locale(negotiated_locale, &)
```

The wrapper is required: Rails has already unwound `around_action` by the time an error renders. Classes sharing a `type` share a title too, so localization cannot leak a hidden distinction.

## Machine-readable detail

RFC 9457 has no member for field errors. Return extension members from the error:

```ruby
def problem_extensions = super.merge(decline_code: @decline_code)
```

Always `super.merge`, so mixins contributing members compose. `Problem::RetryAfter` (`retry_after:`) sends `Retry-After` and a `retry_after` member.

Without protobuf, field errors from a failed save become an extension member of the invalid-record problem:

```ruby
# The record the request would save fails validation.
class InvalidRecord < ApiError
  type "invalid-record"
  status 422
  title "Invalid Record"

  def initialize(record:)
    @record = record
    super(detail: record.errors.full_messages.join("; "))
  end

  def problem_extensions
    super.merge(errors: @record.errors.map { {field: it.attribute.to_s, message: it.message, reason: it.type.to_s} })
  end
end
```

With protobufable, `Protobufable::Problem::Information` carries packed `google.rpc.*` messages such as `BadRequest` in `information`; sponsor-app's `Errors::InvalidRecord` maps each model error to a `FieldViolation` on the request's Input field (see /sorah-guides:rails-protobuf).

## Testing

- Request specs assert the status, `Content-Type: application/problem+json`, and `type`, not the title or `detail` wording.
- Cover at least one escaped error (routing, malformed body) through the exceptions app.

## Caveats

- The top-level constant is `Problem`; an app with its own `Problem` model has a Zeitwerk conflict to resolve.
- `application/problem+xml` is not implemented.
