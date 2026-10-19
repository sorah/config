# frozen_string_literal: true

Rails.application.configure do
  adapter = case ENV['JOB_ADAPTER']
  when 'lambdakiq'
    :lambdakiq
  else
    :inline
  end
  ActiveJob::Base.queue_adapter = config.active_job.queue_adapter = adapter
end
