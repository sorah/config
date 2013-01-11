#!/usr/bin/env ruby
# Usage:
# -- Basic
# $ glitch_word.rb あいう
# うううあああいい
#
# -- Separate argument to keep order of words
# $ glitch_word.rb 壊れていません 、 大丈夫 です
# いいまま壊壊壊壊壊壊んんててせせれれ、、、、、、丈丈丈大大夫夫夫すすでででででで


def glitch(word, max_sequence = ENV["SEQ"] ? ENV["SEQ"].to_i : 3, max_chunks = ENV["CHUNK"] ? ENV["CHUNK"].to_i : 1)
  word.chars.map.with_index do |x, i|
    [[x] * rand(max_sequence).succ] * rand(max_chunks).succ
  end.shuffle.flatten.join
end

puts ARGV.map { |_| glitch _ }.join
