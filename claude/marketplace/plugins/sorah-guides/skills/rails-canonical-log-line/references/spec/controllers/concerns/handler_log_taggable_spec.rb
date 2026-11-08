# frozen_string_literal: true

require "rails_helper"

RSpec.describe HandlerLogTaggable, type: :controller do
  controller(ApplicationController) do
    def index
      render json: {tags: RequestLogContext.tags}
    end
  end

  before do
    routes.draw do
      get "index" => "anonymous#index"
    end
  end

  it "tags log lines with controller#action as handler" do
    get :index

    expect(response.parsed_body.dig("tags", "handler")).to eq("anonymous#index")
  end

  it "keeps the handler tag for lines logged after the action" do
    named_tags = nil
    subscriber = ActiveSupport::Notifications.subscribe("process_action.action_controller") do
      log = SemanticLogger::Log.new("Test", :info)
      SemanticLogger::Logger.call_subscribers(log)
      named_tags = log.named_tags
    end

    get :index

    expect(named_tags).to include(handler: "anonymous#index")
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end
end
