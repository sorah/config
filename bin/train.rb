#!/usr/bin/env ruby
# coding: utf-8
require 'open-uri'

CACHE = "/tmp/train.rb.cache"

if File.exist?(CACHE) && (Time.now - File::Stat.new(CACHE).mtime) <= 300
  print File.read(CACHE)
  exit
end

train_info = open('http://traininfo.jreast.co.jp/train_info/kanto.aspx','r',&:read)
m = train_info.scan(/宇都宮線|湘南新宿ライン|高崎線|埼京線|山手線/).flatten
result = m.empty? ? "" : " #{m.join(", ")} "
open(CACHE, 'w'){|io| io.print result }
print result
