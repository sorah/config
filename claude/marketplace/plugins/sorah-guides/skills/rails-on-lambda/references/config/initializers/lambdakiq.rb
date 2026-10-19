# frozen_string_literal: true

ActiveJob::Base.include Lambdakiq::Worker
ActiveJob::Base.queue_as ENV['LAMBDAKIQ_QUEUE'] if ENV['LAMBDAKIQ_QUEUE']
ActionMailer::MailDeliveryJob.include Lambdakiq::Worker
ActionMailer::MailDeliveryJob.queue_as ENV['LAMBDAKIQ_QUEUE'] if ENV['LAMBDAKIQ_QUEUE']
