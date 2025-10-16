require 'bundler/setup'
require 'papercraft'

t = ->(title:) {
  html {
    body {
      h1 title
    }
  }
}

p Papercraft.ast(t)
puts
puts Papercraft.compiled_code(t)
puts
p Papercraft.source_map(t)
puts
puts Papercraft.html(t, title: 'Hello, world!')
