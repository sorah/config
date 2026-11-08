# frozen_string_literal: true

module MyApp
  # rails_semantic_logger's ActionController subscriber, logging the Completed line of a
  # 5xx response at error and naming the status and handler in its message.
  class ActionControllerLogSubscriber < RailsSemanticLogger::ActionController::LogSubscriber
    # Routes the upstream subscriber's hard-coded info call to error.
    class ErrorLevelLogger < SimpleDelegator
      def info(*args, **kwargs, &block)
        __getobj__.error(*args, **kwargs, &block)
      end
    end

    def process_action(event)
      exception = event.payload[:exception]
      event.payload[:error_class] ||= exception.first if exception
      super
    end

    private def controller_logger(event)
      logger = super
      return logger unless event.name == "process_action.action_controller" && event.payload[:status].to_i >= 500

      ErrorLevelLogger.new(logger)
    end

    private def action_message(message, payload)
      handler = "#{payload[:controller].to_s.underscore.delete_suffix("_controller")}##{payload[:action]}"
      [message, payload[:status], handler].compact.join(" ")
    end
  end
end
