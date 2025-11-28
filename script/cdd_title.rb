# frozen_string_literal: true
a = ENV["PWD"];
a = a
  .sub(ENV["HOME"],"~")
  .sub(%r{^~/git/}, '@/')
  .sub(%r{^@/github.com/(.+?)/([^/]+)}, "\uE001\\2/")
  .split(/\//)
a << "/" if a.empty?
print (a[0] != "\uE001" && a.size > 4 ? a[0..-2].map{|x| x[0] == "\uE001" ? x : x[0] } << a[-1] : a).join("/").gsub(/\uE001/,'')
