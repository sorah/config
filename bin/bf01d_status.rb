#!/usr/bin/env ruby
require 'open-uri'
require 'nokogiri'

router, pass = ARGV[0..1]
url = "http://#{router}:8888/status"

begin
  xml_ = open(url, http_basic_authentication: ['root', pass], &:read)
rescue Exception; exit 1; end
xml = Nokogiri::XML.parse(xml_)


battery = xml.at('pwrStatus power battery').inner_text.to_i

route = xml.at('pwrStatus routeInterface').inner_text.to_i
routex = xml.at("pwrStatus interface[id='#{route}']")

print "BF-01D #{battery}% - "
case route
when 0
  puts " Wi-Fi: #{routex.at('ssid').inner_text} (#{routex.at('rssi').inner_text})"
when 1
  puts " #{routex.at('lte').inner_text == 'true' ? "LTE" : "3G"} (#{routex.at('rssi').inner_text})"
when 2
  puts " Ethernet"
end
