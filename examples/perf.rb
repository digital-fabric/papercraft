require 'rubyoshka'
require 'erubis'
require 'erb'
require 'benchmark/ips'
require 'tilt'
require 'escape_utils'

App = H {
  cache {
    html5 {
      body {
        Header(title: 'My app') {
          button "1"
          button "2"
        }
        Content {}
      }
    }
  }
}

Header = ->(title:, &children) {
  H {
    header {
      h2(title, id: 'title')
      emit children
    }
  }
}

Content = H {
  article {
    h3 context[:title]
    p "Hello, world!"
    div {
      a(href: 'http://google.com/?a=1&b=2&c=3 4') { h3 "foo bar" }
      p "lorem ipsum "
    }
  }
}

HTML_APP = <<~HTML
<!DOCTYPE html>
<html>
  <body>
    <%= render_erubis_header(title: 'MyApp') %>
    <%= render_erubis_content %>
  </body>
</html>
HTML

HTML_HEADER = <<~HTML
<header>
  <h2 id="title"><%= EscapeUtils.escape_html(title) %></h2>
  <button>1</button>
  <button>2</button>
</header>
HTML

HTML_CONTENT = <<~HTML
<article>
  <h3>title from context</h3>
  <p>Hello, world!</p>
  <div>
    <a href="<%= EscapeUtils.escape_uri('http://google.com/?a=1&b=2&c=3%204') %>">
      <h3>foo bar</h3>
    </a>
    <p>lorem ipsum </p>
  </div>
</article>
HTML

class Renderer
  def render_erubis_app
    @erubis_app ||= Tilt::ErubisTemplate.new { HTML_APP }
    @erubis_app.render(self)
  end

  def render_erubis_header(locals)
    @erubis_header ||= Tilt::ErubisTemplate.new { HTML_HEADER }
    @erubis_header.render(self, locals)
  end

  def render_erubis_content
    @erubis_content ||= Tilt::ErubisTemplate.new { HTML_CONTENT }
    @erubis_content.render(self)
  end

  def render_erb_app
    @erb_app ||= Tilt::ERBTemplate.new { HTML_APP }
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


  def render_rubyoshka_app
    App.render(title: 'title from context')
  end

  def render_rubyoshka_content
    Content.render(title: 'title from context')
  end
end

r = Renderer.new

puts r.render_rubyoshka_app
puts r.render_rubyoshka_app

puts "=== Template with 2 partials"
Benchmark.ips do |x|
  x.config(:time => 3, :warmup => 1)

  x.report("rubyoshka") { r.render_rubyoshka_app }
  x.report("erubis") { r.render_erubis_app }
  # x.report("erb") { r.render_erb_app }

  x.compare!
end

# puts "=== Single template"
# Benchmark.ips do |x|
#   x.config(:time => 3, :warmup => 1)

#   x.report("rubyoshka") { r.render_rubyoshka_content }
#   x.report("erubis") { r.render_erubis_content }
#   # x.report("erb") { r.render_erb_content }

#   x.compare!
# end
