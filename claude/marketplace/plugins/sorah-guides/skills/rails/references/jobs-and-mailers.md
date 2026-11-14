# ActiveJob and ActionMailer Patterns

## ApplicationJob

```ruby
class ApplicationJob < ActiveJob::Base
  include CurrentTenantJob

  self.enqueue_after_transaction_commit = true
end
```

- `enqueue_after_transaction_commit` holds the job until the enclosing transaction commits, so a worker never picks up a job naming rows it cannot see yet. Never override it per job. `ActionMailer::MailDeliveryJob` does not inherit `ApplicationJob`, so also set `config.active_job.enqueue_after_transaction_commit = true` in the jobs initializer (it applies to `ActiveJob::Base`) or `deliver_later` still enqueues before commit.
- The queue name comes from configuration (`queue_as { Rails.configuration.x.jobs.default_queue }`), not a literal symbol. A hardcoded `queue_as :mailers` silently sends the job to a queue no worker may be reading.
- The adapter is chosen in `config/initializers/active_job.rb` from configuration. Rails' per-environment defaults (`:test`, `:async`) apply when it is unset.

## Propagating request context into jobs

A `CurrentAttributes` value (tenant, locale, trace ID) that a job needs is captured at enqueue and restored around `perform`, so job classes never pass it by hand:

```ruby
module CurrentTenantJob
  extend ActiveSupport::Concern

  included do
    around_perform :with_tenant_context
  end

  def serialize
    super.merge("_tenant_id" => Current.tenant_id)
  end

  def deserialize(job_data)
    super
    @tenant_id = job_data["_tenant_id"]
  end

  # rescue_from, retry_on and discard_on handlers run after around_perform has unwound.
  def rescue_with_handler(exception)
    with_tenant_context { super }
  end

  private def with_tenant_context(&)
    Current.set(tenant_id: @tenant_id, &)
  end
end
```

- The `rescue_with_handler` wrap matters for `retry_on ... do |job, error|` exhaustion blocks that enqueue mail or log with context.
- A trace or correlation ID propagated the same way joins the job's logs and audit entries to the request that enqueued it.

## Mail delivery

`ActionMailer::MailDeliveryJob` inherits `ActiveJob::Base`, not `ApplicationJob`, so `deliver_later` loses whatever `ApplicationJob` adds. Mix the concern in from the mailer initializer:

```ruby
# config/initializers/mailer.rb
Rails.application.config.to_prepare do
  ActionMailer::MailDeliveryJob.include(CurrentTenantJob) unless ActionMailer::MailDeliveryJob.include?(CurrentTenantJob)
end
```

`to_prepare` makes the autoloaded concern reachable during boot and re-applies it after each reload. `MailDeliveryJob` is not reloaded, so each reload includes a fresh copy of a reloadable concern; keep the concern in `lib/` or an `autoload_once_paths` directory when that matters. A queue adapter's worker mixin (Lambdakiq, Sidekiq) and the queue name need the same treatment on `MailDeliveryJob`, or mail goes to a different queue than every other job.

## ApplicationMailer

```ruby
class ApplicationMailer < ActionMailer::Base
  include TenantMailer

  layout "mailer"
  default from: -> { email_address_with_name(from_email_address, service_name) }
end
```

- Branding (`from`, display name, footer, base URLs) comes from helpers on a mailer concern reading the current context. The helpers raise when the context is missing, so mail never goes out unbranded or under another tenant's name.
- Establish the context before composing, not just before delivering. `deliver_later` snapshots it at enqueue time.
- Put previews where the specs live: add `spec/mailers/previews` to `config.action_mailer.preview_paths`.

## Interceptors

Register interceptors in the same `to_prepare` block, after unregistering the previous copies (`Mail.delivery_interceptors` needs mail 2.9+). `Mail.register_interceptor` deduplicates by object identity, so each Zeitwerk reload otherwise stacks another copy and repeats its effect (a subject prefix applied twice).

```ruby
Rails.application.config.to_prepare do
  interceptors = [SubjectEnvPrefixInterceptor, RecipientAllowlistInterceptor]
  names = interceptors.map(&:name)
  Mail.delivery_interceptors.delete_if { names.include?(it.name) }
  interceptors.each { ActionMailer::Base.register_interceptor(it) }
end
```

Useful interceptors, applied in order:

- **Environment subject prefix**: `[STAGING] ` outside production, from `config.x.mailer.subject_env_prefix`.
- **Recipient allowlist**: In a non-production deployment, filter `to`/`cc`/`bcc` to allowed domains; when nothing remains, set `message.perform_deliveries = false` so the message stays visible to observers and tests but is never sent. Drive the list from configuration (or per-tenant data), with an empty list meaning no filtering.

## Delivery methods

All delivery-method switches live in `config/initializers/mailer.rb` (see the Configuration example in SKILL.md): `:letter_opener_web` in development, `:test` under test, a real transport (`:ses_v2`, SMTP) everywhere else including staging, where the recipient allowlist keeps it safe.

## Common job kinds

A new job usually belongs to one of these:

| Kind | Trigger | Note |
|---|---|---|
| Cascade | A record is revoked or deleted; dependents must follow | One job per level, each enqueuing the next |
| Purge on issuance | Issuing a new record; old ones are cleaned up off the request path | Compute the `cutoff` at enqueue time and pass it, so a delayed job deletes no newer rows |
| Timestamp stamping | Activity needs recording without a write on the request | Coalesce to a resolution (e.g. 10 minutes) to bound write amplification |
| Outbox / delivery | An event or email has to leave the process | Enqueued after commit; idempotent on the outbox row's state |
