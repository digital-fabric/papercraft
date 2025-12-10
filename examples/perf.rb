# frozen_string_literal: true

require 'bundler/inline'

gemfile do
  gem 'papercraft', path: '.'
  gem 'benchmark'
  gem 'benchmark-ips'
  gem 'phlex'
end

require 'papercraft'
require 'erb'
require 'benchmark/ips'
require 'cgi'
require 'phlex'

App = ->(title:) {
  html5 {
    body {
      render(Header, title: title)
      render(Content, title: title)
    }
  }
}

Header = ->(title:) {
  header {
    h2(title, id: 'title')
    button "1"
    button "2"
  }
}

Content = ->(title:) {
  article {
    h3 title
    p "Hello, world!"
    div {
      a(href: 'http://google.com/?a=1&b=2&c=3 4') { h3 "foo bar" }
      p "lorem ipsum"
    }
  }
}

HTML_APP_ERB = <<~HTML
<!DOCTYPE html>
<html>
  <body>
    <%= render_erb_header(title: 'title from context') %>
    <%= render_erb_content(title: 'title from context') %>
  </body>
</html>
HTML

HTML_HEADER_ERB = <<~HTML
<header>
  <h2 id="title"><%= ERB::Escape.html_escape(title) %></h2>
  <button>1</button>
  <button>2</button>
</header>
HTML

HTML_CONTENT_ERB = <<~HTML
<article>
  <h3><%= ERB::Escape.html_escape(title) %></h3>
  <p>Hello, world!</p>
  <div>
    <a href="<%= 'http://google.com/?a=1&b=2&c=3%204' %>">
      <h3>foo bar</h3>
    </a>
    <p>lorem ipsum</p>
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

  def view_template
    doctype
    html {
      body {
        render PhlexHeader.new(title: @title)
        render PhlexContent.new(title: @title)
      }
    }
  end
end

class PhlexHeader < Phlex::HTML
  def initialize(title:)
    @title = title
  end

  def view_template
    header {
      h2(id: 'title') { @title }
      button { "1" }
      button { "2" }
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
  def render_papercraft_app
    Papercraft.html(App, title: 'title from context')
  end

  def render_phlex_app
    # we can't do that: phlex components can be rendered only once
    # @phlex_app ||= PhlexApp.new(title: 'title from context')
    # @phlex_app.call

    PhlexApp.new(title: 'title from context').call
  end

  class_eval(c = <<~RUBY)
    # frozen_string_literal: true
    def render_erb_app
      #{ERB.new(HTML_APP_ERB).src}
    end

    def render_erb_header(title:)
      #{ERB.new(HTML_HEADER_ERB).src}
    end

    def render_erb_content(title:)
      #{ERB.new(HTML_CONTENT_ERB).src}
    end
  RUBY
end

r = Renderer.new

# puts '* Papercraft:'
# puts r.render_papercraft_app
# puts

# puts '* Phlex:'
# puts r.render_phlex_app
# puts

# puts '* ERB:'
# puts r.render_erb_app.gsub(/\n\s+/, '')

Benchmark.ips do |x|
  # x.config(:time => 5, :warmup => 2)

  x.report("erb") { r.render_erb_app }
  x.report("papercraft") { r.render_papercraft_app }
  x.report("phlex") { r.render_phlex_app }

  x.compare!(order: :baseline)
end
