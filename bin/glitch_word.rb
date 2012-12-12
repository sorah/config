#!/usr/bin/env ruby
# Usage:
# -- Basic
# $ glitch_word.rb あいう
# うううあああいい
#
# -- Separate argument to keep order of words
# $ glitch_word.rb 壊れていません 、 大丈夫 です
# いいまま壊壊壊壊壊壊んんててせせれれ、、、、、、丈丈丈大大夫夫夫すすでででででで


def glitch(word, max_sequence=2, max_chunks=3)
  word.chars.map do |x|
    [[x] * rand(max_sequence).succ] * rand(max_chunks).succ
  end.shuffle.flatten.join
end

puts ARGV.map { |_| glitch _ }.join
