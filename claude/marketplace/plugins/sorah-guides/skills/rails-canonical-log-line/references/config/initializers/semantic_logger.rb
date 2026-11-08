# frozen_string_literal: true

# Tags every line of a request with what the raw request carries.
class RequestLogTagger
  def initialize(app)
    @app = app
  end

  def call(env)
    SemanticLogger.tagged(tags(env)) { @app.call(env) }
  end

  private def tags(env)
    {
      request_id: env["action_dispatch.request_id"],
      amzn_trace_id: env["HTTP_X_AMZN_TRACE_ID"],
    }.compact
  end
end

Rails.application.config.middleware.insert_after(ActionDispatch::RequestId, RequestLogTagger)

SemanticLogger.on_log { |log| RequestLogContext.apply(log) }

ActiveSupport::Notifications.subscribe("rescue_from_callback.action_controller") do |event|
  RequestLogContext.rescued_exception = event.payload[:exception]
end

ActiveSupport::Notifications.subscribe("enqueue.active_job") { RequestLogContext.increment(:jobs_enqueued) }
ActiveSupport::Notifications.subscribe("deliver.action_mailer") { RequestLogContext.increment(:mails_delivered) }

Rails.application.config.after_initialize do
  RailsSemanticLogger.swap_subscriber(
    RailsSemanticLogger::ActionController::LogSubscriber,
    MyApp::ActionControllerLogSubscriber,
    :action_controller,
  )
  Rails.event.subscribe(RequestLogContext::AuditEventSubscriber.new) { |event| event[:name] == "audit_log.entry" }
end
