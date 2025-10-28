# frozen_string_literal: true

require 'erb'
require 'benchmark/ips'

TEMPLATE_ERB = <<~HTML
  <div>
    <h1><%= 'foo' %></h1>
    <p><%= 'bar' %></p>
  </div>
HTML

TEMPLATE_DSL = proc {
  div {
    h1 'foo'
    p 'bar'
  }
}

class Renderer
  def render_dsl(template)
    @buffer = +''
    instance_eval(&template)
    @buffer
  end

  def div(&block)
    @buffer << '<div>'
    instance_eval(&block)
    @buffer << '</div>'
  end

  def h1(text)
    @buffer << "<h1>#{text}</h1>"
  end

  def p(text)
    @buffer << "<p>#{text}</p>"
  end

  class_eval(c = <<~RUBY)
    # frozen_string_literal: true
    def render_erb
      #{ERB.new(TEMPLATE_ERB).src}
    end
  RUBY
end

r = Renderer.new

puts '* ERB:'
puts r.render_erb
puts

puts '* DSL:'
puts r.render_dsl(TEMPLATE_DSL)
puts

puts
puts ERB.new(TEMPLATE_ERB).src
puts

Benchmark.ips do |x|
  # x.config(:time => 5, :warmup => 2)

  x.report("ERB") { r.render_erb }
  x.report("DSL") { r.render_dsl(TEMPLATE_DSL) }

  x.compare!(order: :baseline)
end
