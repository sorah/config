# frozen_string_literal: true

# Request-scoped named tags carried by every log line written after they are added,
# including the ActionController "Completed" line, and counters of the work done during
# the request that the Completed line reports.
class RequestLogContext < ActiveSupport::CurrentAttributes
  attribute :tags, default: -> { {} }
  attribute :rescued_exception
  attribute :counters, default: -> { Hash.new(0) }
  attribute :rate_limits, default: -> { {} }
  attribute :audit_event_ids, default: -> { [] }

  def self.add_tags(**new_tags)
    tags.merge!(new_tags)
  end

  def self.increment(key)
    counters[key] += 1
  end

  # Keeps the inputs of each rate limit evaluated during the request, by kind.
  def self.record_rate_limit(kind, **inputs)
    rate_limits[kind] = inputs
  end

  def self.record_audit_event_id(event_id)
    audit_event_ids << event_id
  end

  # Tags from an enclosing `SemanticLogger.tagged` block win on a shared key.
  def self.apply(log)
    return if tags.empty?

    log.named_tags = tags.merge(log.named_tags)
  end

  def self.log_payload
    payload = counters.to_h
    payload[:rate_limits] = rate_limits unless rate_limits.empty?
    payload[:audit_event_ids] = audit_event_ids unless audit_event_ids.empty?
    payload
  end

  # Records the id of every audit event emitted through Rails.event during the request.
  class AuditEventSubscriber
    def emit(event)
      event_id = event.fetch(:payload)[:event_id]
      RequestLogContext.record_audit_event_id(event_id) if event_id
    end
  end
end
