# frozen_string_literal: true

require 'bundler/inline'

gemfile do
  gem 'p2', path: '.'
  gem 'benchmark-ips', '>= 2.14.0'
  gem 'tilt'
  gem 'erubi'
  gem 'phlex'
end

require 'p2'
require 'erb'
require 'erubi'
require 'benchmark/ips'
require 'cgi'
require 'tilt'
require 'phlex'

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

HTML_APP_ERUBI = <<~HTML
<!DOCTYPE html>
<html>
  <body>
    <%= render_erubi_header(title: 'title from context') %>
    <%= render_erubi_content %>
  </body>
</html>
HTML

HTML_HEADER_ERUBI = <<~HTML
<header>
  <h2 id="title"><%= CGI.escapeHTML(title) %></h2>
  <button>1</button>
  <button>2</button>
</header>
HTML

HTML_CONTENT_ERUBI = <<~HTML
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
  def view_template
    doctype
    html {
      body {
        render PhlexHeader.new(title: @title) do
          button { '1' }
          button { '2' }
        end
        render PhlexContent.new(title: @title)
      }
    }
  end
end

class PhlexApp < Phlex::HTML
  def initialize(title:)
    @title = title
  end
end

class PhlexHeader < Phlex::HTML
  def initialize(title:)
    @title = title
  end

  def view_template
    header {
      h2(id: 'title') { @title }
      yield
    }
  end
end

class PhlexContent < Phlex::HTML
  def initialize(title:)
    @title = title
  end

  def view_template
    article {
      h3 { @title }
      p { "Hello, world!" }
      div {
        a(href: 'http://google.com/?a=1&b=2&c=3 4') { h3 { "foo bar" } }
        p { "lorem ipsum " }
      }
    }
  end
end

class Renderer
  def render_p2_app
    App.render(title: 'title from context')
  end

  def render_phlex_app
    # we can't do that: phlex components can be rendered only once
    # @phlex_app ||= PhlexApp.new(title: 'title from context')
    # @phlex_app.call

    PhlexApp.new(title: 'title from context').call
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

  ERUBI_OPTS = {
    chain_appends: true,
    freeze_template_literals: false,
    bufval: "+''",
    escape: true,
  }
  class_eval(c = <<~RUBY)
    # frozen_string_literal: true
    def render_erubi_app
      #{Erubi::Engine.new(HTML_APP_ERUBI, ERUBI_OPTS).src}
    end

    def render_erubi_header(title:)
      #{Erubi::Engine.new(HTML_HEADER_ERUBI, ERUBI_OPTS).src}
    end

    def render_erubi_content
      #{Erubi::Engine.new(HTML_CONTENT_ERUBI, ERUBI_OPTS).src}
    end
  RUBY
end

r = Renderer.new

puts '* P2:'
puts r.render_p2_app
puts

puts '* Phlex:'
puts r.render_phlex_app
puts

puts '* TILT+ERB:'
puts r.render_erb_app.gsub(/\n\s+/, '')

puts '* ERUBI (raw):'
puts r.render_erubi_app.gsub(/\n\s+/, '')

Benchmark.ips do |x|
  # x.config(:time => 5, :warmup => 2)

  x.report("p2") { r.render_p2_app }
  x.report("phlex") { r.render_phlex_app }
  x.report("tilt+erb") { r.render_erb_app }
  x.report("erubi") { r.render_erubi_app }

  x.compare!(order: :baseline)
end
