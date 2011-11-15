require 'irb/completion'
#require 'irbtools'
require 'what_methods'
require 'pp'

module Kernel
  def pp(*x)
    PP.pp(*x)
    nil
  end

  def clear
    system "clear"
  end
end

IRB.conf[:AUTO_INDENT]=true
IRB.conf[:SAVE_HISTORY]=200
IRB.conf[:PROMPT_MODE] = :simple
