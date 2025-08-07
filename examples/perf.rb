require 'bundler/setup'
require 'p2'
require 'erb'
require 'benchmark/ips'
require 'cgi'
require 'tilt'

App = ->(title:) {
  html5 {
    body {
      emit(Header, title: title) {
        button "1"
        button "2"
      }
      emit(Content, title: title)
    }
  }
}

Header = ->(title:) {
  header {
    h2(title, id: 'title')
    emit_yield
  }
}

Content = ->(title:) {
  article {
    h3 title
    p "Hello, world!"
    div {
      a(href: 'http://google.com/?a=1&b=2&c=3 4') { h3 "foo bar" }
      p "lorem ipsum "
    }
  }
}

HTML_APP_ERB = <<~HTML
<!DOCTYPE html>
<html>
  <body>
    <%= render_erb_header(title: 'title from context') %>
    <%= render_erb_content %>
  </body>
</html>
HTML

HTML_HEADER = <<~HTML
<header>
  <h2 id="title"><%= CGI.escapeHTML(title) %></h2>
  <button>1</button>
  <button>2</button>
</header>
HTML

HTML_CONTENT = <<~HTML
<article>
  <h3>title from context</h3>
  <p>Hello, world!</p>
  <div>
    <a href="<%= 'http://google.com/?a=1&b=2&c=3%204' %>">
      <h3>foo bar</h3>
    </a>
    <p>lorem ipsum </p>
  </div>
</article>
HTML

class Renderer
  def render_erb_app
    @erb_app ||= ERB.new(HTML_APP_ERB)
    @erb_app.result(binding)
  end

  # def render_erb_header(**locals)
  #   @erb_header ||= ERB.new(HTML_HEADER)
  #   @erb_header.result_with_hash(**locals)
  # end

  # def render_erb_content
  #   @erb_content ||= ERB.new(HTML_CONTENT)
  #   @erb_content.result
  # end

  def render_p2_app
    App.render(title: 'title from context')
  end

  def render_erb_app
    @erb_app ||= Tilt::ERBTemplate.new { HTML_APP_ERB }
    @erb_app.render(self)
  end

  def render_erb_header(locals)
    @erb_header ||= Tilt::ERBTemplate.new { HTML_HEADER }
    @erb_header.render(self, locals)
  end

  def render_erb_content
    @erb_content ||= Tilt::ERBTemplate.new { HTML_CONTENT }
    @erb_content.render(self)
  end
end

r = Renderer.new

puts '* P2:'
puts r.render_p2_app
puts

puts '* ERB:'
puts r.render_erb_app.gsub(/\n\s+/, '')

Benchmark.ips do |x|
  # x.config(:time => 5, :warmup => 2)

  x.report("p2") { r.render_p2_app }
  x.report("erb") { r.render_erb_app }

  x.compare!
end
