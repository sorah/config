#!/usr/bin/env ruby
# coding: utf-8
require 'open-uri'

CACHE = "/tmp/train.rb.cache"

if File.exist?(CACHE) && (Time.now - File::Stat.new(CACHE).mtime) <= 300
  print File.read(CACHE)
  exit
end

train_info = open('http://traininfo.jreast.co.jp/train_info/kanto.aspx','r',&:read)
#m = train_info.scan(/宇都宮線|湘南新宿ライン|高崎線|埼京線|山手線/).flatten.uniq
m = train_info.scan(%r{<td align="left".*?>(?:<font color="White"><b>)?<font class="px12" size="3"><a href="history\.aspx.*?">(.+?)</a>(?:</font></b>)?</font></td><td align="center".*?>(?:<font class="White"><b>)?<font class="px12" size="3">(.+?)</font>}).uniq.map{|x| x.join(":").gsub(/&nbsp;/,'') }
result = m.empty? ? "" : " #{m.join(", ")} "
open(CACHE, 'w'){|io| io.print result }
print result





