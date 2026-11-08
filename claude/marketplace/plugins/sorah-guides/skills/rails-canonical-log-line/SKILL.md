---
name: rails-canonical-log-line
description: This skill should be used when making a Rails app's request log answer who made a request and how it went, such as when the ActionController "Completed" line lacks the user, session or error behind a request, when tags set in an `around_action` with `logger.tagged` are missing from the Completed line, or when adding request-wide fields, work counters or a status-based log level to it. Use it whenever the user mentions "canonical log line", "Completed line", "request log", "log tags", "named tags", "process_action payload", "append_info_to_payload", "rails_semantic_logger", "SemanticLogger.tagged" or "on_log", or asks to "log the user id on every line", "log why a request failed" or "make 5xx log at error", even if they only say "the logs don't say who made the request". Provides a CurrentAttributes log context merged into every line, outcome fields on the Completed payload, per-request counters, a status-based level and message, and specs for each. Project-specific conventions always take priority.
version: 0.1.0
---

# Canonical Log Lines on Rails

One line per request that says who made it, what handled it, how it ended and what work it did, after Stripe's [canonical log lines](https://stripe.com/blog/canonical-log-lines). In a Rails app on [rails_semantic_logger](https://github.com/reidmorrison/rails_semantic_logger), that line already exists: the ActionController `Completed` line. The work is making it carry the request's context, not adding another line. Taken from a production rollout on Rails 8.1, rails_semantic_logger 4.19 and semantic_logger 4.17. Project-specific conventions (CLAUDE.md, `docs/`) always take priority.

## Why the Completed line loses context

- `Completed` is logged by a `process_action.action_controller` subscriber when `ActionController::Instrumentation#process_action` finishes, outside the callback chain. An `around_action { logger.tagged(user_id: ...) { yield } }` has already unwound by then. Lines logged inside the action carry the tags, `Completed` does not.
- A Rack middleware's `SemanticLogger.tagged` block does wrap `Completed`, but it runs before routing and authentication, so it can tag only what the raw request carries.
- An error handled by `rescue_from` never reaches `payload[:exception]`, so a 4xx line has no reason. rails_semantic_logger deletes `:exception` from the payload of an unhandled one.
- rails_semantic_logger logs `Completed` at `info` whatever the status, and the Rack `Started` line at `info` too. Every request writes two lines and a 500 looks like a 200.

## The pieces

| Piece | Purpose | Reference |
|---|---|---|
| `RequestLogContext` (`ActiveSupport::CurrentAttributes`) | Request-scoped tags and counters | `app/models/request_log_context.rb` |
| `SemanticLogger.on_log` hook | Merges the context's tags into every line as it is written | `config/initializers/semantic_logger.rb` |
| `RequestLogTagger` middleware | Tags from the raw request: `request_id`, trace ids | same initializer |
| `HandlerLogTaggable` concern | `handler` tag, set before any other callback | `app/controllers/concerns/handler_log_taggable.rb` |
| `ActionLogPayloadable` concern | Outcome fields and counters on the `Completed` payload | `app/controllers/concerns/action_log_payloadable.rb` |
| `MyApp::ActionControllerLogSubscriber` | Level by status, status and handler in the message | `lib/my_app/action_controller_log_subscriber.rb` |

`references/` mirrors an app's tree, with a spec for each piece under `references/spec/`. Copy the files and replace `MyApp`. The subscriber lives in `lib/` and needs `config.autoload_lib`.

## Request-wide tags: a CurrentAttributes context

Keep tags in a `CurrentAttributes` class instead of a `tagged` block, and merge them into each line from an `on_log` subscriber:

```ruby
class RequestLogContext < ActiveSupport::CurrentAttributes
  attribute :tags, default: -> { {} }

  def self.add_tags(**new_tags) = tags.merge!(new_tags)

  def self.apply(log)
    return if tags.empty?

    log.named_tags = tags.merge(log.named_tags)
  end
end

# config/initializers/semantic_logger.rb
SemanticLogger.on_log { |log| RequestLogContext.apply(log) }
```

- semantic_logger calls `on_log` subscribers inline in the thread that logs, before queuing the line for the appender thread, so `Current` values are visible there. Never read `Current` from an appender or formatter: they run on the appender thread.
- An enclosing `tagged` block wins on a shared key (`tags.merge(log.named_tags)`), so a narrower scope can still override.
- The executor resets `CurrentAttributes` per request and per job. Nothing leaks between requests and no `ensure` is needed.
- A tag applies to lines written after `add_tags`, never retroactively. Add each identifier as soon as it is known: the handler in a `prepend_before_action`, the user where authentication resolves it.

```ruby
# Where authentication resolves the user, in a before_action.
RequestLogContext.add_tags(user_id: current_user_maybe&.id, session_id: current_session_maybe&.id)
```

Put a tag in the context only when it identifies the request: user, session, tenant, client, handler. A value that describes one event belongs in that line's payload.

The middleware tags what the raw request carries. Insert it after `ActionDispatch::RequestId`, so `action_dispatch.request_id` is set, and add `request_id` as a named tag. Keep an unnamed `config.log_tags = [:request_id]` as well when a tracer's log correlation (such as Datadog's) reads the unnamed tag.

## Outcome fields: `append_info_to_payload`

`ActionController::Instrumentation` calls `append_info_to_payload(payload)` in an `ensure`, after the action and every `rescue_from` handler, and rails_semantic_logger copies every key into the `Completed` payload. Override it in a concern included in `ApplicationController`, calling `super`:

| Field | Source |
|---|---|
| `ip`, `user_agent` | `request.remote_ip`, `request.user_agent` |
| `locale`, API versions or previews the request opted into | the app's own negotiation methods |
| `error_class` | the exception a `rescue_from` handled |
| `problem_type` | `error.class.type` when the error is `Problem::Detailable` (/sorah-guides:rails-problem) |
| Domain error codes | e.g. an OAuth `error` code declared on the error class |
| Join keys | ids another system records too, such as the audit event the request wrote |

The rescued exception is not in the payload. Record it in the context from the `rescue_from_callback.action_controller` notification (Rails 8.1+):

```ruby
ActiveSupport::Notifications.subscribe("rescue_from_callback.action_controller") do |event|
  RequestLogContext.rescued_exception = event.payload[:exception]
end
```

Before Rails 8.1, override `rescue_with_handler` in the concern to record the exception and call `super`.

- Read values from controller methods, not from state an `around_action` set. `I18n.with_locale` has unwound by the time the hook runs, so `I18n.locale` is the default again.
- Add a field when it describes the request as a whole; per-event detail stays in its own line.
- `filter_parameters` filters `params` but not fields added here. Never add request bodies, tokens or other secrets.

## Counters

Count the work a request did, so the line explains its duration and side effects: database retries, jobs enqueued, mails delivered, external API calls, cache refreshes. Keep counters in the same context and merge `RequestLogContext.log_payload` into the payload.

```ruby
attribute :counters, default: -> { Hash.new(0) }

def self.increment(key) = counters[key] += 1
```

- Prefer a notification subscriber to a call site: `enqueue.active_job` for `jobs_enqueued`, `deliver.action_mailer` for `mails_delivered`. Increment at the call site only where no event exists, such as a retry loop.
- Report a counter only when non-zero. The line stays short and a missing key reads as zero.
- For a decision made from several inputs, such as a rate limit, record the inputs by kind (`record_rate_limit(:login, window_count:, window_limit:)`), not only the verdict. One request can evaluate several, so key them by kind rather than keeping the last.
- To collect ids of events the app emits through `Rails.event` (Rails 8.1+), subscribe an object with `#emit(event)` and a filter block, in `config.after_initialize`.

The context fills during jobs too. Nothing reports it there unless jobs get their own canonical line, for example from a `perform.active_job` subscriber.

## Level and message: a subscriber subclass

rails_semantic_logger hard-codes `info` in `process_action`. Subclass its `ActionController::LogSubscriber` and swap it in:

- Override the private `controller_logger(event)` to wrap the logger in a delegator whose `info` calls `error` when the status is 5xx. Keep 4xx at `info`: the client caused it, and an alert on it fires on bad input.
- Override `process_action` to copy `payload[:exception].first` into `payload[:error_class]` before `super` deletes `:exception`. Use `||=` so the rescued error recorded by the concern wins.
- Override the private `action_message(message, payload)` to name the status and handler: `Completed 401 users/sessions#show`. Without a subclass, `config.rails_semantic_logger.action_message_format` takes a lambda for the message alone.
- Swap it in `config.after_initialize` with `RailsSemanticLogger.swap_subscriber(RailsSemanticLogger::ActionController::LogSubscriber, MyApp::ActionControllerLogSubscriber, :action_controller)`.
- Set `config.rails_semantic_logger.started = false` in `config/application.rb` to log `Started` at debug. Its method, path and IP are all on `Completed`.

A new message breaks saved searches and monitors that match `"Completed #action"` exactly. Say so in the pull request.

## Testing

- Give the context's spec a Rails example group type (`type: :model`), so rspec-rails resets `CurrentAttributes` between examples.
- Exercise the `on_log` hook with `SemanticLogger::Logger.call_subscribers(log)` on a `SemanticLogger::Log.new("Test", :info)`. No appender is needed.
- Prove a tag survives the callback chain: in a controller spec, subscribe to `process_action.action_controller`, log from the subscriber, and assert the tag is on that line. An assertion made inside the action passes even with the broken `around_action`.
- Spec the payload concern from an anonymous controller with a `process_action.action_controller` subscriber that captures `event.payload`, one action per outcome.
- Spec the subscriber with hand-built `ActiveSupport::Notifications::Event`s, capturing lines with `SemanticLogger::Test::CaptureLogEvents` stubbed in as the controller's `logger`. Assert the swap took effect from `ActiveSupport::LogSubscriber.subscribers`.
- Controller specs skip the middleware stack, so `action_dispatch.request_id` is unset there. Cover the middleware's tags in a request spec.
- `include ActiveJob::TestHelper` for the `jobs_enqueued` counter, so enqueuing goes to the test adapter.

## Querying

With the JSON formatter, named tags land under `named_tags` and payload fields under `payload`. Document the fields in the app's `docs/`, with the query forms the team uses, such as Datadog's `@named_tags.user_id:u_123 @payload.problem_type:not-found`.
