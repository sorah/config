# Logging with rails_semantic_logger

[rails_semantic_logger](https://logger.rocketjob.io/rails.html) replaces `Rails.logger` with a SemanticLogger instance. Levels: `trace`, `debug`, `info`, `warn`, `error`, `fatal`.

## Call shapes

```ruby
logger.info(message)
logger.info(message, payload)
logger.info(message, exception)
logger.info(message, payload, exception)
logger.info(message, payload:, exception:)
```

```ruby
Rails.logger.info("User logged in", user_id: 42)
Rails.logger.warn("Rate limit approaching", current_count: 95, limit: 100)
Rails.logger.error("Payment processing failed", {order_id: 123, amount: 9900}, error)
```

Passing the exception as its own argument records its class, message and full backtrace as structured fields:

```ruby
# Good
Rails.logger.error("Something went wrong", error)

# Bad - backtrace lost, class and message flattened into prose
Rails.logger.error("Something went wrong: #{error.message}")
Rails.logger.error("Something went wrong", message: error.message)
```

Enumerated payload values are Symbols (`reason: :window_exceeded`).

## Expensive payloads

```ruby
if Rails.logger.debug?
  Rails.logger.debug("Debug data", detail: calculate_debug_info)
end
```

## Measuring duration

`measure_<level>` logs the block's duration in milliseconds:

```ruby
Rails.logger.measure_info("External API call", payload: {api: "billing"}) do
  client.retrieve(customer_id)
end
```

## Recovering and reporting

Errors that propagate are logged and reported by the framework (Rails, sentry-rails). Report explicitly only where code rescues to recover:

```ruby
def fetch_cached_value(key)
  cache.fetch(key)
rescue Redis::CannotConnectError => e
  Rails.logger.warn("Cache unavailable, falling back to database", {key:}, e)
  Sentry.capture_exception(e, level: :warning)
  database_fallback(key)
end
```

Sentry levels: `:debug`, `:info`, `:warning`, `:error`, `:fatal`. Use `:warning` for recoverable errors worth watching.

## References

- [SemanticLogger API](https://logger.rocketjob.io/api.html)
- [Rails integration](https://logger.rocketjob.io/rails.html)
