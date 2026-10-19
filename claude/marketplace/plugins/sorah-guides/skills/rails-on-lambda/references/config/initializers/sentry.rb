# frozen_string_literal: true

Sentry.init do |config|
  config.dsn = ENV['SENTRY_DSN']
  # Lambda freezes the environment once the handler returns, so events are sent inline.
  config.background_worker_threads = 0 if ENV['AWS_LAMBDA_FUNCTION_NAME']
end
