#!/usr/bin/env ruby
require 'bundler/inline'
gemfile do
  source 'https://rubygems.org'
  gem 'httpx'
end

require 'httpx'
require 'socket'
require 'json'

payload = JSON.parse($stdin.read)

response = HTTPX.post('https://api.pushover.net/1/messages.json', form: {
  token: ENV.fetch('PUSHOVER_API_TOKEN'),
  user: ENV.fetch('PUSHOVER_USER_KEY'),
  title: "Claude #{payload['cwd']&.then { File.basename(it) }}: #{payload['title'] || 'Notification'} (#{Socket.gethostname})",
  message: payload['message'] || '-no message-',
})

response.raise_for_status
puts response.body
