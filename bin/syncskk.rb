#!/usr/bin/env ruby

OKURI_ARI_HEAD = ";; okuri-ari entries."
OKURI_NASI_HEAD = ";; okuri-nasi entries."

abort "Usage: #{$0} workdir" if ARGV.empty?

workdir = ARGV[0]
hostname = ENV["HOSTNAME"] || `hostname`.chomp
mine = File.expand_path('~/.skk-jisyo')
target = File.expand_path('~/.skk-jisyo.sync')

okuris = {}
nookuris = {}

Dir["#{workdir}/*"].each do |path|
  next if File.basename(path) == hostname


end
