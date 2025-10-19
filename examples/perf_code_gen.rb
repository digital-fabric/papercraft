# frozen_string_literal: true

require 'bundler/inline'

gemfile do
  gem 'papercraft', path: '.'
  gem 'benchmark-ips', '>= 2.14.0'
end

require 'papercraft'
require 'erb'
require 'benchmark/ips'

class PapercraftBaseline
  App = ->(title:) {
    html5 {
      body {
        render(Header, title: title) {
          button "1"
          button "2"
        }
        render(Content, title: title)
      }
    }
  }

  Header = ->(title:) {
    header {
      h2(title, id: 'title')
      render_yield
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
end

class PapercraftNoYield
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
end

class Coalesced
  App = ->(_b_, title:) do
    _b_ << "<!DOCTYPE html><html><body>#{
      Papercraft.render_emit_call(Header, title: title, &(->(_b_) {
        ; _b_ << "<button>1</button><button>2</button>"
      }.__papercraft_compiled!))
      }#{
      Papercraft.render_emit_call(Content, title: title)
      }</body></html>";
    _b_
  rescue Exception => e
    raise e;
  end.__papercraft_compiled!

  Header = ->(_b_, title:, &__block__) do
    _b_ << "<header><h2 id=\"title\">#{
      ERB::Escape.html_escape((title).to_s)
    }</h2>"
    (__block__ ? __block__.render_to_buffer(_b_) : raise(LocalJumpError, 'no block given (yield)'))
    _b_ << "</header>"
    _b_
  rescue Exception => e
    raise e
  end.__papercraft_compiled!

  Content = ->(_b_, title:) do
    _b_ << "<article><h3>#{ERB::Escape.html_escape((title).to_s)}</h3><p>Hello, world!</p><div><a href=\"http://google.com/?a=1&b=2&c=3 4\"><h3>foo bar</h3></a><p>lorem ipsum</p></div></article>"
    _b_
  rescue Exception => e
    raise e
  end.__papercraft_compiled!
end

class Chunked
  App = ->(_b_, title:) do
    _b_ << "<!DOCTYPE html><html><body>" <<
        Papercraft.render_emit_call(Header, title: title, &(->(_b_) {
        ; _b_ << "<button>1</button><button>2</button>"
        }.__papercraft_compiled!)) <<
        Papercraft.render_emit_call(Content, title: title) <<
        "</body></html>";
    _b_
  rescue Exception => e
    raise e;
  end.__papercraft_compiled!

  Header = ->(_b_, title:, &__block__) do
    _b_ << "<header><h2 id=\"title\">" <<
        ERB::Escape.html_escape((title).to_s) <<
        "</h2>"
    (__block__ ? __block__.render_to_buffer(_b_) : raise(LocalJumpError, 'no block given (yield)'))
    _b_ << "</header>"
    _b_
  rescue Exception => e
    raise e
  end.__papercraft_compiled!

  Content = ->(_b_, title:) do
    _b_ << "<article><h3>" <<
      ERB::Escape.html_escape((title).to_s) <<
      "</h3><p>Hello, world!</p><div><a href=\"http://google.com/?a=1&b=2&c=3 4\"><h3>foo bar</h3></a><p>lorem ipsum</p></div></article>"
    _b_
  rescue Exception => e
    raise e
  end.__papercraft_compiled!
end

class DirectInvocation
  App = ->(_b_, title:) do
    _b_ << "<!DOCTYPE html><html><body>"
    Header.compiled_proc.(_b_, title: title, &(->(_b_) {
      ; _b_ << "<button>1</button><button>2</button>"
    }).__papercraft_compiled!)
    Content.compiled_proc.(_b_, title: title)
    _b_ << "</body></html>";
    _b_
  rescue Exception => e
    raise e;
  end.__papercraft_compiled!

  Header = ->(_b_, title:, &__block__) do
    _b_ << "<header><h2 id=\"title\">" <<
        ERB::Escape.html_escape((title).to_s) <<
        "</h2>"
    (__block__ ? __block__.render_to_buffer(_b_) : raise(LocalJumpError, 'no block given (yield)'))
    _b_ << "</header>"
    _b_
  rescue Exception => e
    raise e
  end.__papercraft_compiled!

  Content = ->(_b_, title:) do
    _b_ << "<article><h3>" <<
      ERB::Escape.html_escape((title).to_s) <<
      "</h3><p>Hello, world!</p><div><a href=\"http://google.com/?a=1&b=2&c=3 4\"><h3>foo bar</h3></a><p>lorem ipsum</p></div></article>"
    _b_
  rescue Exception => e
    raise e
  end.__papercraft_compiled!
end

class Inlined
  App = ->(_b_, title:) do
    _b_ << "<!DOCTYPE html><html><body>"

    _b_ << "<header><h2 id=\"title\">"
    _b_ << ERB::Escape.html_escape((title).to_s)
    _b_ << "</h2><button>1</button><button>2</button></header>"

    _b_ << "<article><h3>"
    _b_ << ERB::Escape.html_escape((title).to_s)
    _b_ << "</h3><p>Hello, world!</p><div><a href=\"http://google.com/?a=1&b=2&c=3 4\"><h3>foo bar</h3></a><p>lorem ipsum</p></div></article>"
    _b_ << "</body></html>";
    _b_
  rescue Exception => e
    raise e;
  end.__papercraft_compiled!

  # Header = ->(_b_, title:, &__block__) do
  #   _b_ << "<header><h2 id=\"title\">" <<
  #       ERB::Escape.html_escape((title).to_s) <<
  #       "</h2>"
  #   (__block__ ? __block__.render_to_buffer(_b_) : raise(LocalJumpError, 'no block given (yield)'))
  #   _b_ << "</header>"
  #   _b_
  # rescue Exception => e
  #   raise e
  # end.__papercraft_compiled!

  # Content = ->(_b_, title:) do
  #   _b_ << "<article><h3>" <<
  #     ERB::Escape.html_escape((title).to_s) <<
  #     "</h3><p>Hello, world!</p><div><a href=\"http://google.com/?a=1&b=2&c=3 4\"><h3>foo bar</h3></a><p>lorem ipsum</p></div></article>"
  #   _b_
  # rescue Exception => e
  #   raise e
  # end.__papercraft_compiled!
end

class NoYield
  App = ->(_b_, title:) do
    _b_ << "<!DOCTYPE html><html><body>"
    Header.compiled_proc.(_b_, title: title)
    Content.compiled_proc.(_b_, title: title)
    _b_ << "</body></html>";
    _b_
  rescue Exception => e
    raise e;
  end.__papercraft_compiled!

  Header = ->(_b_, title:) do
    _b_ << "<header><h2 id=\"title\">" <<
        ERB::Escape.html_escape((title).to_s) <<
        "</h2><button>1</button><button>2</button></header>"
    _b_
  rescue Exception => e
    raise e
  end.__papercraft_compiled!

  Content = ->(_b_, title:) do
    _b_ << "<article><h3>" <<
      ERB::Escape.html_escape((title).to_s) <<
      "</h3><p>Hello, world!</p><div><a href=\"http://google.com/?a=1&b=2&c=3 4\"><h3>foo bar</h3></a><p>lorem ipsum</p></div></article>"
    _b_
  rescue Exception => e
    raise e
  end.__papercraft_compiled!
end

class NoYieldSeparate
  App = ->(_b_, title:) do
    _b_ << "<!DOCTYPE html><html><body>"
    Header.compiled_proc.(_b_, title: title)
    Content.compiled_proc.(_b_, title: title)
    _b_ << "</body></html>";
    _b_
  rescue Exception => e
    raise e;
  end.__papercraft_compiled!

  Header = ->(_b_, title:) do
    _b_ << "<header><h2 id=\"title\">"
    _b_ << ERB::Escape.html_escape((title).to_s)
    _b_ << "</h2><button>1</button><button>2</button></header>"
    _b_
  rescue Exception => e
    raise e
  end.__papercraft_compiled!

  Content = ->(_b_, title:) do
    _b_ << "<article><h3>"
    _b_ << ERB::Escape.html_escape((title).to_s)
    _b_ << "</h3><p>Hello, world!</p><div><a href=\"http://google.com/?a=1&b=2&c=3 4\"><h3>foo bar</h3></a><p>lorem ipsum</p></div></article>"
    _b_
  rescue Exception => e
    raise e
  end.__papercraft_compiled!
end

class NoRescue
  App = ->(_b_, title:) do
    _b_ << "<!DOCTYPE html><html><body>"
    Header.compiled_proc.(_b_, title: title, &(->(_b_) {
      ; _b_ << "<button>1</button><button>2</button>"
    }).__papercraft_compiled!)
    Content.compiled_proc.(_b_, title: title)
    _b_ << "</body></html>";
    _b_
  end.__papercraft_compiled!

  Header = ->(_b_, title:, &__block__) do
    _b_ << "<header><h2 id=\"title\">" <<
        ERB::Escape.html_escape((title).to_s) <<
        "</h2>"
    (__block__ ? __block__.render_to_buffer(_b_) : raise(LocalJumpError, 'no block given (yield)'))
    _b_ << "</header>"
    _b_
  end.__papercraft_compiled!

  Content = ->(_b_, title:) do
    _b_ << "<article><h3>" <<
      ERB::Escape.html_escape((title).to_s) <<
      "</h3><p>Hello, world!</p><div><a href=\"http://google.com/?a=1&b=2&c=3 4\"><h3>foo bar</h3></a><p>lorem ipsum</p></div></article>"
    _b_
  end.__papercraft_compiled!
end

class Separate
  App = ->(_b_, title:) do
    _b_ << "<!DOCTYPE html><html><body>"
    _b_ << Papercraft.render_emit_call(Header, title: title, &(->(_b_) {
        ; _b_ << "<button>1</button><button>2</button>"
        }.__papercraft_compiled!))
    _b_ << Papercraft.render_emit_call(Content, title: title)
    _b_ << "</body></html>";
    _b_
  rescue Exception => e
    raise e;
  end.__papercraft_compiled!

  Header = ->(_b_, title:, &__block__) do
    _b_ << "<header><h2 id=\"title\">"
    _b_ << ERB::Escape.html_escape((title).to_s)
    _b_ << "</h2>"
    (__block__ ? __block__.render_to_buffer(_b_) : raise(LocalJumpError, 'no block given (yield)'))
    _b_ << "</header>"
    _b_
  rescue Exception => e
    raise e
  end.__papercraft_compiled!

  Content = ->(_b_, title:) do
    _b_ << "<article><h3>"
    _b_ << ERB::Escape.html_escape((title).to_s)
    _b_ << "</h3><p>Hello, world!</p><div><a href=\"http://google.com/?a=1&b=2&c=3 4\"><h3>foo bar</h3></a><p>lorem ipsum</p></div></article>"
    _b_
  rescue Exception => e
    raise e
  end.__papercraft_compiled!
end

class CompiledERB
  def render_app(title:)
    _erbout = +''; _erbout.<< "<!DOCTYPE html>\n<html>\n  <body>\n    ".freeze
    ; _erbout.<<(( render_header(title: title) ).to_s); _erbout.<< "\n    ".freeze
    ; _erbout.<<(( render_content(title: title) ).to_s); _erbout.<< "\n  </body>\n</html>\n".freeze
    ; _erbout
  end

  def render_header(title:)
    _erbout = +''; _erbout.<< "<header>\n  <h2 id=\"title\">".freeze
    ; _erbout.<<(( ERB::Escape.html_escape(title) ).to_s); _erbout.<< "</h2>\n  <button>1</button>\n  <button>2</button>\n</header>\n".freeze
    ; _erbout
  end

  def render_content(title:)
    _erbout = +''; _erbout.<< "<article>\n  <h3>".freeze
    ; _erbout.<<(( ERB::Escape.html_escape(title) ).to_s); _erbout.<< "</h3>\n  <p>Hello, world!</p>\n  <div>\n    <a href=\"".freeze
    ; _erbout.<<(( 'http://google.com/?a=1&b=2&c=3%204' ).to_s); _erbout.<< "\">\n      <h3>foo bar</h3>\n    </a>\n    <p>lorem ipsum</p>\n  </div>\n</article>\n".freeze
    ; _erbout
  end
end

class CompiledERubi
  def render_app(title:)
    _buf = +'';; _buf << '<!DOCTYPE html>
<html>
  <body>
    ' << ( render_header(title: title) ).to_s << '
' << '    ' << ( render_content(title: title) ).to_s << '
' << '  </body>
</html>
'
; _buf.to_s
  end

  def render_header(title:)
    _buf = +'';; _buf << '<header>
  <h2 id="title">' << ( ERB::Escape.html_escape(title) ).to_s << '</h2>
  <button>1</button>
  <button>2</button>
</header>
'
; _buf.to_s
  end

  def render_content(title:)
    _buf = +'';; _buf << '<article>
  <h3>' << ( ERB::Escape.html_escape(title) ).to_s << '</h3>
  <p>Hello, world!</p>
  <div>
    <a href="' << ( 'http://google.com/?a=1&b=2&c=3%204' ).to_s << '">
      <h3>foo bar</h3>
    </a>
    <p>lorem ipsum</p>
  </div>
</article>
'
    ; _buf.to_s
  end
end

# puts "Coalesced:"
# puts Coalesced::App.(+'', title: 'title')
# puts

# puts "Chunked:"
# puts Chunked::App.(+'', title: 'title')
# puts

puts "Inlined:"
puts Inlined::App.(+'', title: 'title')
puts

# puts "No rescue:"
# puts Chunked::App.(+'', title: 'title')
# puts

# puts "Direct invocation:"
# puts DirectInvocation::App.(+'', title: 'title')
# puts

# puts "Without yield:"
# puts NoYield::App.(+'', title: 'title')
# puts

# puts "Without yield separate:"
# puts NoYieldSeparate::App.(+'', title: 'title')
# puts

# puts "Compiled ERB:"
# puts CompiledERB.new.render_app(title: 'title')
# puts

# puts "Compiled ERubi:"
# puts CompiledERubi.new.render_app(title: 'title')
# puts

puts "Papercraft baseline:"
puts Papercraft.html(PapercraftBaseline::App, title: 'title')
puts

puts "Papercraft no yield:"
puts Papercraft.html(PapercraftNoYield::App, title: 'title')
puts

cerb = CompiledERB.new
cerubi = CompiledERubi.new

Benchmark.ips do |x|
  # x.config(:time => 5, :warmup => 2)

  x.report("ERB") { cerb.render_app(title: 'title from context') }
  x.report("ERubi") { cerubi.render_app(title: 'title from context') }
  x.report("papercraft baseline") { Papercraft.html(PapercraftBaseline::App, title: 'title from context') }
  x.report("papercraft no yield") { Papercraft.html(PapercraftNoYield::App, title: 'title from context') }

  x.report("inlined") { Inlined::App.(+'', title: 'title from context') }

  # x.report("coalesced") { Coalesced::App.(+'', title: 'title from context') }
  # x.report("chunked") { Chunked::App.(+'', title: 'title from context') }
  # x.report("direct invoke") { DirectInvocation::App.(+'', title: 'title from context') }
  # x.report("no yield") { NoYield::App.(+'', title: 'title from context') }
  # # x.report("no rescue") { NoRescue::App.(+'', title: 'title from context') }
  # x.report("no yield (separate)") { NoYieldSeparate::App.(+'', title: 'title from context') }

  x.compare!(order: :baseline)
end
