#!/usr/bin/env ruby
# coding: utf-8
require 'open-uri'
require 'cgi'

CACHE = "/tmp/weather.rb.cache"

if File.exist?(CACHE) && (Time.now - File::Stat.new(CACHE).mtime) <= 300
  print File.read(CACHE)
  exit
end

locations = {"Minato, Tokyo" => "港", "Utsunomiya, Tochigi" => '鬱'}

def api_url(location)
  "http://www.google.com/ig/api?hl=en&weather=#{CGI.escape(location)}"
end

urls = locations.map{|l, s| [api_url(l), s] }

def condition_to_symbol(condition)
  case condition.downcase
  when /sunny$/
    h = Time.now.hour
    (22 < h || h < 5) ? "☾" : "☀"
  when /(rain|drizzle|showers)$/, "flurries"
    "☔"
  when /snow( showers)?$/, "sleet", "icy"
    "❅"
  when /cloudy$/, "overcast"
    "☁"
  when /storms?$/
    "⚡"
  when 'dust', 'fog', 'smoke', 'haze', 'mist'
    "♨"
  when 'windy'
    "⚑"
  when 'clear'
    "✈"
  else
    "[#{condition}]"
  end
end

def weather(url)
  xml = open(url, 'r', &:read)
  current = xml.match(/<current_conditions>(.+?)<\/current_conditions>/)[1]
  forecast = xml.match(/<forecast_conditions>(.+?)<\/forecast_conditions>/)[1]
  current_sym = condition_to_symbol(current.match(/<condition data="(.+?)" ?\/>/)[1])
  current_temp = current.match(/<temp_c data="(.+?)" ?\/>/)[1] + "C"
  forecast_sym = forecast ? "#{condition_to_symbol(forecast.match(/<condition data="(.+?)" ?\/>/)[1])}" : ""
  "#{current_sym} #{current_temp}#{forecast_sym}"
rescue Exception
  nil
end

error = false
result = urls.map { |url, s|
  w = weather(url)
  error = true if w.nil?
  "#{s}#{w || "✗>_<✗"}"
}.join("  ")+" "

if error
  File.delete CACHE
else
  open(CACHE, 'w'){|io| io.print result }
end

print "✱ "+result
