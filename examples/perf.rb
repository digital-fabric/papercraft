require_relative '../lib/rubyoshka'
require 'erubis'
require 'erb'
require 'benchmark/ips'

App = H {
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
  <h2 id="title"><%= title %></h2>
  <button>1</button>
  <button>2</button>
</header>
HTML

HTML_CONTENT = <<~HTML
<article>
  <h3>title from context</h3>
  <p>Hello, world!</p>
  <div>
    <a href="http://google.com/?a=1&b=2&c=3%204">
      <h3>foo bar</h3>
    </a>
    <p>lorem ipsum </p>
  </div>
</article>
HTML

def render_erubis_app
  Erubis::Eruby.new(HTML_APP).result(binding)
end

def render_erubis_header(title:)
  Erubis::Eruby.new(HTML_HEADER).result(binding)
end

def render_erubis_content
  Erubis::Eruby.new(HTML_CONTENT).result(binding)
end

def render_erb_app
  ERB.new(HTML_APP).result(binding)
end

def render_erb_header(title:)
  ERB.new(HTML_HEADER).result(binding)
end

def render_erb_content
  ERB.new(HTML_CONTENT).result(binding)
end


def render_rubyoshka_app
  App.render(title: 'title from context')
end

Benchmark.ips do |x|
  x.config(:time => 3, :warmup => 1)

  x.report("rubyoshka") { render_rubyoshka_app }
  x.report("erubis") { render_erubis_app }
  x.report("erb") { render_erb_app }

  x.compare!
end