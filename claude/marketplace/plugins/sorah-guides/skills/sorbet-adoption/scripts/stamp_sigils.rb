#!/usr/bin/env ruby
# frozen_string_literal: true

# Usage: stamp_sigils.rb [--level false] FILE...
#
# Inserts `# typed: <level>` as the first line of each Ruby file that has no
# sigil yet. A shebang stays first. Prints the paths it changed.

level = "false"
if ARGV.first == "--level"
  ARGV.shift
  level = ARGV.shift or abort "--level needs a value"
end
abort "usage: #{$PROGRAM_NAME} [--level LEVEL] FILE..." if ARGV.empty?

ARGV.each do |path|
  lines = File.readlines(path)
  # Sorbet reads the sigil only from the leading comment block.
  next if lines.take_while { |l| l.start_with?("#") || l.strip.empty? }.any? { |l| l.match?(/\A#\s*typed:/) }

  at = lines.first&.start_with?("#!") ? 1 : 0
  lines.insert(at, "# typed: #{level}\n")
  File.write(path, lines.join)
  puts path
end
