#!/usr/bin/env ruby
# frozen_string_literal: true

# Usage: stamp_rbs_inline.rb FILE...
#
# Inserts `# rbs_inline: enabled` into each Ruby file that has no rbs_inline
# magic comment yet, right after the leading shebang, encoding and
# frozen_string_literal lines. Prints the paths it changed.

abort "usage: #{$PROGRAM_NAME} FILE..." if ARGV.empty?

ARGV.each do |path|
  lines = File.readlines(path)
  header = lines.take_while { |l| l.start_with?("#") || l.strip.empty? }
  next if header.any? { |l| l.match?(/\A#\s*rbs_inline:/) }

  at = lines.take_while { |l| l.match?(/\A#(!|\s*(frozen_string_literal|encoding|coding):)/) }.size
  lines.insert(at, "# rbs_inline: enabled\n")
  File.write(path, lines.join)
  puts path
end
