# frozen_string_literal: true

require "rails_helper"

RSpec.describe ActionLogPayloadable, type: :controller do
  controller(ApplicationController) do
    def index
      render json: {}
    end

    def count
      RequestLogContext.increment(:mails_delivered)
      render json: {}
    end

    def problem
      raise Errors::NotFound
    end
  end

  let(:payload) { {} }

  around do |example|
    subscriber = ActiveSupport::Notifications.subscribe("process_action.action_controller") do |event|
      payload.replace(event.payload)
    end
    example.run
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end

  before do
    routes.draw do
      get "index" => "anonymous#index"
      get "count" => "anonymous#count"
      get "problem" => "anonymous#problem"
    end
  end

  it "adds request details" do
    request.headers["User-Agent"] = "RSpec"
    request.headers["Accept-Language"] = "ja"

    get :index

    expect(payload).to include(ip: "0.0.0.0", user_agent: "RSpec", locale: "ja")
  end

  it "adds the request log context counters" do
    get :count

    expect(payload).to include(mails_delivered: 1)
  end

  it "adds no error fields on success" do
    get :index

    expect(payload.keys).not_to include(:error_class, :problem_type)
  end

  it "adds the class and problem type of a rescued error" do
    get :problem

    expect(payload).to include(error_class: "Errors::NotFound", problem_type: "not-found")
  end
end
