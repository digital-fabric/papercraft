# frozen_string_literal: true

require_relative './helper'
require_relative '../lib/papercraft/compiler'

  # x = 42
  # span 'x'
  # span x + 1
  # span "a#{x + 2}\"\""
  # span true
  # span false
  # span nil

  # br
  
  # span 'foo', a: 1, b: :bar, c: '"c&d"', d: true, e: false

t = -> {
  bar = 'baz'
  div(class: 'bar') {
    bar = bar * 3
    p bar
  }
  br
  emit '!abc!'
  bar = 'bazzz'
}
puts '*' * 40

code = Papercraft::TemplateCompiler.compile_to_code(t)


# t_compiled = Papercraft::TemplateCompiler.compile(t)

# puts t_compiled

puts '*' * 40

puts code

# puts t_compiled.(+'')
