# frozen_string_literal: true

ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

require "bundler/setup"
require "bootsnap/setup"
require_relative "lambda_boot" if ENV['AWS_LAMBDA_FUNCTION_NAME']
