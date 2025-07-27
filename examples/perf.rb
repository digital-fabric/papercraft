require 'bundler/setup'
require 'papercraft'
require 'papercraft/compiler'
require 'erubis'
require 'erb'
require 'benchmark/ips'
require 'tilt'
require 'cgi'

App = Papercraft.html { |title:|
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

Header = Papercraft.html { |title:|
  header {
    h2(title, id: 'title')
    emit_yield
  }
}

Content = Papercraft.html { |title:|
  article {
    h3 title
    p "Hello, world!"
    div {
      a(href: 'http://google.com/?a=1&b=2&c=3 4') { h3 "foo bar" }
      p "lorem ipsum "
    }
  }
}

HTML_APP_ERUBIS = <<~HTML
<!DOCTYPE html>
<html>
  <body>
    <%= render_erubis_header(title: 'MyApp') %>
    <%= render_erubis_content %>
  </body>
</html>
HTML

HTML_APP_ERB = <<~HTML
<!DOCTYPE html>
<html>
  <body>
    <%= render_erb_header(title: 'MyApp') %>
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
  def render_erubis_app
    @erubis_app ||= Tilt::ErubisTemplate.new { HTML_APP_ERUBIS }
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


  def render_papercraft_app
    App.render(title: 'title from context') 
  end

  # def render_papercraft_content
  #   Content.render(title: 'title from context')
  # end
  # 
  AppCompiledCode = Papercraft::TemplateCompiler.compile_to_code(App)
  AppCompiledProc = Papercraft::TemplateCompiler.compile(App)

  def render_papercraft_compiled_app

    buffer = +''
    AppCompiledProc.(buffer, title: 'title from context')
    buffer
  end
end

r = Renderer.new

puts '* Papercraft:'
puts r.render_papercraft_app
puts
puts '* Papercraft (compiled):'
puts r.render_papercraft_compiled_app
puts

puts '* ERubis:'
puts r.render_erubis_app.gsub(/\n\s*/, '')
puts

puts '* ERB:'
puts r.render_erb_app.gsub(/\n\s+/, '')

puts "=== Single template"
Benchmark.ips do |x|
  x.config(:time => 5, :warmup => 2)

  x.report("papercraft") { r.render_papercraft_app }
  x.report("papercraft (compiled)") { r.render_papercraft_compiled_app }
  x.report("erubis") { r.render_erubis_app }
  x.report("erb") { r.render_erb_app }

  x.compare!
end
