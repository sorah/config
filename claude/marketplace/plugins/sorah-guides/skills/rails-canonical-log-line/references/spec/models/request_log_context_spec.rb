# frozen_string_literal: true

require "rails_helper"

RSpec.describe RequestLogContext, type: :model do
  include ActiveJob::TestHelper

  def log_with(named_tags)
    SemanticLogger::Log.new("Test", :info).tap { |log| log.named_tags = named_tags }
  end

  describe ".apply" do
    it "adds the context tags to the log's named tags" do
      described_class.add_tags(user_id: "u_1")
      log = log_with(request_id: "r_1")

      described_class.apply(log)

      expect(log.named_tags).to eq(request_id: "r_1", user_id: "u_1")
    end

    it "keeps the value from an enclosing tagged block on a shared key" do
      described_class.add_tags(handler: "a#b")
      log = log_with(handler: "x#y")

      described_class.apply(log)

      expect(log.named_tags).to eq(handler: "x#y")
    end

    it "leaves the log untouched when no tags were added" do
      log = log_with(request_id: "r_1")

      described_class.apply(log)

      expect(log.named_tags).to eq(request_id: "r_1")
    end
  end

  describe ".log_payload" do
    it "is empty when nothing was recorded" do
      expect(described_class.log_payload).to eq({})
    end

    it "flattens counters and nests rate limits and audit event ids" do
      described_class.increment(:db_retries)
      described_class.increment(:db_retries)
      described_class.record_rate_limit(:login, window_count: 2, window_limit: 30)
      described_class.record_audit_event_id("ev_1")

      expect(described_class.log_payload).to eq(
        db_retries: 2,
        rate_limits: {login: {window_count: 2, window_limit: 30}},
        audit_event_ids: ["ev_1"],
      )
    end
  end

  it "records the id of each emitted audit event" do
    RequestLogContext::AuditEventSubscriber.new.emit({name: "audit_log.entry", payload: {event_id: "ev_1"}})

    expect(described_class.audit_event_ids).to eq(["ev_1"])
  end

  it "counts enqueued jobs" do
    stub_const("NoopJob", Class.new(ApplicationJob) { def perform; end })

    expect { NoopJob.perform_later }.to change { described_class.counters[:jobs_enqueued] }.by(1)
  end

  it "applies to every log line through SemanticLogger's on_log hook" do
    described_class.add_tags(user_id: "u_1")
    log = log_with({})

    SemanticLogger::Logger.call_subscribers(log)

    expect(log.named_tags).to include(user_id: "u_1")
  end
end
