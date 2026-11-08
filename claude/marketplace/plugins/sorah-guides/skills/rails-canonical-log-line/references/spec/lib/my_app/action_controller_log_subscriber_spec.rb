# frozen_string_literal: true

require "rails_helper"
require "semantic_logger/test/capture_log_events"

RSpec.describe MyApp::ActionControllerLogSubscriber do
  let(:logger) { SemanticLogger::Test::CaptureLogEvents.new }

  before do
    allow(ApplicationController).to receive(:logger).and_return(logger)
  end

  def process_action(**payload)
    event = ActiveSupport::Notifications::Event.new(
      "process_action.action_controller",
      0,
      1,
      "id",
      {controller: "ApplicationController", action: "index", method: "GET", path: "/", **payload},
    )
    described_class.new.process_action(event)
    logger.events.last
  end

  it "replaces the upstream subscriber" do
    subscribers = ActiveSupport::LogSubscriber.subscribers.grep(RailsSemanticLogger::ActionController::LogSubscriber)

    expect(subscribers.map(&:class)).to eq([described_class])
  end

  it "names the status and handler in the message" do
    expect(process_action(status: 200).message).to eq("Completed 200 application#index")
  end

  [200, 302, 404, 422].each do |status|
    it "logs a #{status} at info" do
      expect(process_action(status:).level).to eq(:info)
    end
  end

  it "logs a 5xx at error" do
    expect(process_action(status: 503).level).to eq(:error)
  end

  it "keeps the class of an unrescued exception" do
    log = process_action(status: 500, exception: ["RuntimeError", "boom"])

    expect(log.level).to eq(:error)
    expect(log.payload).to include(error_class: "RuntimeError")
  end
end
