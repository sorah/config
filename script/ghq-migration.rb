#!/usr/bin/env ruby
# Based https://github.com/hsbt/scripts/blob/master/git-go.rb
require 'uri'
require 'fileutils'

TARGET = ENV['TARGET'] || "~/git"

warn = []

[Dir.glob(ARGV[0] || '*/*')].flatten.each do |dir|
  next unless File.directory? dir
  next if dir.start_with? 'config'
  remote_url = Dir.chdir(dir) do
    next unless File.directory?('.git')
    remotes = `git remote -v`.chomp
    next if remotes.empty?
    if remotes.match(/^origin/)
      remotes.scan(/origin\t(.*) \(fetch\)/).first[0]
    else
      x = remotes.scan(/(?:.+?)\t(.*) \(fetch\)/).first[0]
      warn << "No origin for #{dir}, using #{x}"
      x
    end
  end

  uri = URI(remote_url.to_s.gsub(/^ssh:\/\//,'').gsub(/:/, '/').gsub(/\/\/\//, '://').gsub(/git@/, 'https://').gsub(/\.git/, ''))
  next unless uri.hostname && uri.path

  h = uri.hostname
  u, _ = *uri.path.scan(/\/?(.+)\/(\w+)\/?/).first

  destination = File.expand_path("#{TARGET}/#{h}/#{u}")
  puts "#{dir} -> #{destination}/#{File.basename(dir)}"
  unless ENV["NOOP"]
    FileUtils.mkdir_p destination
    FileUtils.mv dir, destination
  end
end

if File.directory?('config')
  destination = File.expand_path(TARGET)
  FileUtils.mkdir_p destination
  FileUtils.mv 'config', destination
end

$stderr.puts warn
