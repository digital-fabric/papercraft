require 'bundler/setup'
require 'minitest/autorun'
require 'rubyoshka'

class CompilerTest < MiniTest::Test
  HTML_ENCODER = ->(t) { EscapeUtils.escape_html(t.to_s) }
  class Rubyoshka::Compiler
    attr_accessor :level
  end

  def compiled_template(tmpl, level = 1)
    c = Rubyoshka::Compiler.new(HTML_ENCODER)
    c.level = level
    c.compile(tmpl)
  end

  def compiled_template_body(tmpl)
    compiled_template(tmpl, 0).code_buffer
  end

  def compiled_template_code(tmpl)
    compiled_template(tmpl).to_code
  end

  def compiled_template_proc(tmpl)
    compiled_template(tmpl).to_proc
  end

  def test_compiler_simple
    templ = H {
      h1 'foo'
      h2 'bar'
    }

    code = compiled_template_code(templ)
    expected = <<~RUBY.chomp
      ->(__buffer__, __context__) do
        __buffer__ << "<h1>foo</h1><h2>bar</h2>"
      end
    RUBY
    assert_equal expected, code
  end

  def test_compiler_simple_with_attributes
    templ = H {
      h1 'foo', class: 'foot'
      h2 'bar', id: 'bar', onclick: "f(\"abc\", \"def\")"
    }

    code = compiled_template_code(templ)
    expected = <<~RUBY.chomp
      ->(__buffer__, __context__) do
        __buffer__ << "<h1 class=\\"foot\\">foo</h1><h2 id=\\"bar\\" onclick=\\"f(&quot;abc&quot;, &quot;def&quot;)\\">bar</h2>"
      end
    RUBY
    assert_equal expected, code

    template_proc = compiled_template_proc(templ)
    buffer = +''
    template_proc.(buffer, nil)
    assert_equal '<h1 class="foot">foo</h1><h2 id="bar" onclick="f(&quot;abc&quot;, &quot;def&quot;)">bar</h2>', buffer
  end

  def test_compiler_conditional_1
    a = true
    template = H {
      h1 (a ? 'foo' : 'bar')
    }

    code = compiled_template_body(template)
    assert_equal "__buffer__ << \"<h1>\#{__html_encode__(a ? \"foo\" : \"bar\")}</h1>\"\n", code
  end

  def test_compiler_conditional_2
    a = true
    template = H {
      header 'hi'
      a ? (p 'foo') : (h3 'bar')
      footer 'bye'
    }

    code = compiled_template_body(template)
    expected = <<~RUBY
      __buffer__ << "<header>hi</header>"
      if a
        __buffer__ << "<p>foo</p>"
      else
        __buffer__ << "<h3>bar</h3>"
      end
      __buffer__ << "<footer>bye</footer>"
    RUBY
    assert_equal expected, code
  end

  def test_compiler_conditional_3
    a = true
    template = H {
      h1 'hi' if a
      h2 'bye' unless a
    }

    code = compiled_template_body(template)
    expected = <<~RUBY
      if a
        __buffer__ << "<h1>hi</h1>"
      end
      unless a
        __buffer__ << "<h2>bye</h2>"
      end
    RUBY
    assert_equal expected, code
  end
end