require 'bundler/setup'
require 'papercraft'

t = ->(title:) {
  html {
    body {
      h1 title
    }
  }
}

p t.ast
puts
puts t.compiled_code
puts
p t.source_map
puts
puts t.render(title: 'Hello, world!')