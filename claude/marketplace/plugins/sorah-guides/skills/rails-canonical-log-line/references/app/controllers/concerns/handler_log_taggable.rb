# frozen_string_literal: true

# Tags every log line of the request with the controller and action handling it.
module HandlerLogTaggable
  extend ActiveSupport::Concern

  included do
    # Prepended so lines logged by authentication and other callbacks carry it too.
    prepend_before_action :set_handler_log_tag
  end

  private def set_handler_log_tag
    RequestLogContext.add_tags(handler: "#{params[:controller]}##{params[:action]}")
  end
end
