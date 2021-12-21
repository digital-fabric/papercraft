# frozen_string_literal: true

require_relative 'lib/papercraft/compiler'
require 'escape_utils'

class T
  attr_reader :block

  def initialize(&block)
    @block = block
  end
end

html_encoder = ->(t) { EscapeUtils.escape_html(t.to_s) }

i = 1
t = T.new do
  h1 @title
end

c = Rubyoshka::Compiler.new(html_encoder)
c.compile(t)
puts c.to_code
