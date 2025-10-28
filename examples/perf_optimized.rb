# frozen_string_literal: true

require 'bundler/inline'

gemfile do
  gem 'papercraft', path: '.'
  gem 'benchmark'
  gem 'benchmark-ips', '>= 2.14.0'
end

require 'papercraft/proc'
require 'erb'
require 'benchmark/ips'

TemplatePapercraft = ->(foo, bar) {
  div {
    h1 foo
    h2 bar
  }
}

TemplateERB = <<~ERB
  <div>
    <h1><%= ERB::Escape.html_escape(foo) %></h1>
    <p><%= ERB::Escape.html_escape(bar) %></p>
  </div>
ERB

def render_papercraft(foo, bar)
  TemplatePapercraft.__papercraft_compiled_proc.(+'', foo, bar)
end

def render_papercraft_optimized(foo, bar)
  TemplatePapercraft.__optimized_html(+'', foo, bar)
rescue => e
  p e
end

puts
TemplatePapercraft.singleton_class.class_eval <<~RUBY.tap { puts it }
  # frozen_string_literal: true
  def __optimized_html(__buffer__, foo, bar)
    __buffer__.<<("<div><h1>").<<(
    ERB::Escape.html_escape((foo))).<<("</h1><h2>").<<(
    ERB::Escape.html_escape((bar))).<<("</h2></div>")
    __buffer__
  end
RUBY
puts

puts
singleton_class.class_eval <<~RUBY.tap { puts it }
  # frozen_string_literal: true
  def render_optimized(foo, bar)
    __buffer__ = +''
    __buffer__.<<("<div><h1>").<<(
    ERB::Escape.html_escape((foo))).<<("</h1><h2>").<<(
    ERB::Escape.html_escape((bar))).<<("</h2></div>")
    __buffer__
  end
RUBY
puts

puts
singleton_class.class_eval <<~RUBY.tap { puts it }
  # frozen_string_literal: true
  def render_erb(foo, bar)
    #{ERB.new(TemplateERB).src}
  rescue => e
    raise e
  end
RUBY
puts

def render_erb_indirect(foo, bar)
  render_erb(foo, bar)
end

puts
puts TemplatePapercraft.compiled_code
puts

puts render_erb('FOO', 'BAR')
puts render_papercraft('FOO', 'BAR')
puts render_optimized('FOO', 'BAR')
puts render_papercraft_optimized('FOO', 'BAR')
puts 

# puts '* ERB:'
# puts r.render_erb_app.gsub(/\n\s+/, '')

# puts '* ERUBI (raw):'
# puts r.render_erubi_app.gsub(/\n\s+/, '')

res = Benchmark.ips do |x|
  # x.config(:time => 5, :warmup => 2)

  x.report("erb") { render_erb('FOO', 'BAR') }
  x.report("erb_indirect") { render_erb_indirect('FOO', 'BAR') }
  x.report("papercraft") { render_papercraft('FOO', 'BAR') }
  x.report("papercraft_optimized") { render_papercraft_optimized('FOO', 'BAR') }
  x.report("optimized") { render_optimized('FOO', 'BAR') }

  x.compare!(order: :baseline)
end


p res