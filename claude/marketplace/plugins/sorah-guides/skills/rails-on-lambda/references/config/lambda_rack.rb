# frozen_string_literal: true

require_relative 'boot'
require 'apigatewayv2_rack'

LambdaRackApp = Apigatewayv2Rack.handler_from_rack_config_file(File.join(__dir__, '..', 'config.ru'))
