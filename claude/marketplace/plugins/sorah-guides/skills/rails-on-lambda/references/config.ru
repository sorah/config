# frozen_string_literal: true

require_relative "config/environment"

if ENV['AWS_LAMBDA_FUNCTION_NAME']
  use Apigatewayv2Rack::Middlewares::CloudfrontVerify, ENV['CLOUDFRONT_VERIFY'] if ENV['CLOUDFRONT_VERIFY']
  use Apigatewayv2Rack::Middlewares::CloudfrontXff
end

run Rails.application
Rails.application.load_server
