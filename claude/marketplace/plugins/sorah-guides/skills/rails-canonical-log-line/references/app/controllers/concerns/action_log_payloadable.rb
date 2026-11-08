# frozen_string_literal: true

# Adds the request's outcome to the process_action.action_controller payload, which
# rails_semantic_logger logs as the "Completed" line.
module ActionLogPayloadable
  extend ActiveSupport::Concern

  private def append_info_to_payload(payload)
    super
    payload.merge!(request_log_payload, error_log_payload, RequestLogContext.log_payload)
  end

  private def request_log_payload
    {
      ip: request.remote_ip,
      user_agent: request.user_agent,
      # I18n.locale is reset by now, as an around_action setting it has unwound.
      locale: negotiated_locale.to_s,
    }
  end

  private def error_log_payload
    error = RequestLogContext.rescued_exception
    return {} unless error

    {error_class: error.class.name, problem_type: problem_type_for(error)}.compact
  end

  private def problem_type_for(error)
    error.class.type if error.is_a?(Problem::Detailable)
  end
end
