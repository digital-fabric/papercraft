require 'bundler/setup'
require 'minitest/autorun'
require 'papercraft'

module ::Kernel
  def C(&block)
    Papercraft::Template.new(&block).compile
      .tap { |c|
        if ENV['DEBUG'] == '1'
          puts '*' * 40; puts c.to_code; puts
        end
      }
      .to_proc
  end

  def c(&block)
    Papercraft::Template.new(&block).compile
    .tap { |c|
      if ENV['DEBUG'] == '1'
        puts '*' * 40; puts c.to_code; puts
      end
    }
end
end

class ::Proc
  def render(*args)
    +''.tap { |b| call(b, *args) }
  end
end

class CompilerTest < Minitest::Test
  class Papercraft::Compiler
    attr_accessor :level
  end

  def compiled_template(tmpl, level = 1)
    c = Papercraft::Compiler.new
    c.compile(tmpl, level)
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

  def template_body(body)
    body.chomp.lines.map { |l| "  #{l}" }.join
  end

  def test_compiler_simple
    templ = Papercraft.html {
      h1 'foo'
      h2 'bar'
    }

    code = compiled_template_code(templ)
    expected = <<~RUBY
      ->(__buffer__, &__block__) do
        __buffer__ << "<h1>foo</h1><h2>bar</h2>"
        __buffer__
      end
    RUBY
    assert_equal template_body(expected), code
  end

  def test_compiler_simple_with_attributes
    templ = Papercraft.html {
      h1 'foo', class: 'foot'
      h2 'bar', id: 'bar', onclick: "f(\"abc\", \"def\")"
    }

    code = compiled_template_code(templ)
    expected = <<~RUBY
      ->(__buffer__, &__block__) do
        __buffer__ << "<h1 class=\\"foot\\">foo</h1><h2 id=\\"bar\\" onclick=\\"f(&quot;abc&quot;, &quot;def&quot;)\\">bar</h2>"
        __buffer__
      end
    RUBY
    assert_equal template_body(expected), code

    template_proc = compiled_template_proc(templ)
    buffer = +''
    template_proc.(buffer)
    assert_equal '<h1 class="foot">foo</h1><h2 id="bar" onclick="f(&quot;abc&quot;, &quot;def&quot;)">bar</h2>', buffer
  end

  def test_compiler_conditional_1
    a = true
    template = Papercraft.html {
      h1 (a ? 'foo' : 'bar')
    }

    code = compiled_template_body(template)
    assert_equal "  __buffer__ << \"<h1>\#{CGI.escapeHTML((a ? \"foo\" : \"bar\").to_s)}</h1>\"\n", code
  end

  def test_compiler_conditional_2
    a = true
    template = Papercraft.html {
      header 'hi'
      a ? (p 'foo'; p 'bar') : (h3 'baz')
      footer 'bye'
    }

    code = compiled_template_body(template)
    expected = <<~RUBY
      __buffer__ << "<header>hi</header>"
      if a
        __buffer__ << "<p>foo</p><p>bar</p>"
      else
        __buffer__ << "<h3>baz</h3>"
      end
      __buffer__ << "<footer>bye</footer>"
    RUBY
    assert_equal template_body(expected), code.chomp
  end

  def test_compiler_conditional_3
    a = true
    template = Papercraft.html {
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
    assert_equal template_body(expected), code.chomp
  end

  def test_compiler_conditional_4
    a = true
    b = true
    template = Papercraft.html {
      if a
        h1 'foo'
      elsif b
        h2 'bar'
      else
        h3 'baz'
      end
    }

    code = compiled_template_body(template)
    expected = <<~RUBY
      if a
        __buffer__ << "<h1>foo</h1>"
      else
        if b
          __buffer__ << "<h2>bar</h2>"
        else
          __buffer__ << "<h3>baz</h3>"
        end
      end
    RUBY
    assert_equal template_body(expected), code.chomp
  end
end

class CompiledTemplateTest < Minitest::Test
  def test_compile
    t = Papercraft.html { h1 'foo' }
    c = t.compile

    assert_kind_of Papercraft::Compiler, c
    p = c.to_proc
    b = +''
    p.(b)

    assert_equal '<h1>foo</h1>', b
  end

  def test_simple_html
    h = C { div { p 'foo'; p 'bar' } }
    assert_equal(
      '<div><p>foo</p><p>bar</p></div>',
      h.render
    )
  end

  def test_that_attributes_are_supported_and_escaped
    assert_equal(
      '<div class="blue and green"/>',
      C { div class: 'blue and green' }.render
    )

    assert_equal(
      '<div onclick="return doit();"/>',
      C { div onclick: 'return doit();' }.render
    )

    assert_equal(
      '<a href="/?q=a%20b"/>',
      C { a href: '/?q=a b' }.render
    )
  end

  def test_that_valueless_attributes_are_supported
    assert_equal(
      '<input type="checkbox" checked/>',
      C { input type: 'checkbox', checked: true }.render
    )

    assert_equal(
      '<input type="checkbox"/>',
      C { input type: 'checkbox', checked: false }.render
    )
  end

  def test_that_tag_method_accepts_no_arguments
    assert_equal(
      '<div/>',
      C { div() }.render
    )
  end

  def test_that_tag_method_accepts_text_argument
    assert_equal(
      '<p>lorem ipsum</p>',
      C { p "lorem ipsum" }.render
    )
  end

  def test_that_tag_method_accepts_non_string_text_argument
    assert_equal(
      '<p>lorem</p>',
      C { p :lorem }.render
    )
  end

  def test_that_tag_method_escapes_string_text_argument
    assert_equal(
      '<p>lorem &amp; ipsum</p>',
      C { p 'lorem & ipsum' }.render
    )
  end

  def test_that_tag_method_accepts_text_and_attributes
    assert_equal(
      '<p class="hi">lorem ipsum</p>',
      C { p "lorem ipsum", class: 'hi' }.render
    )
  end

  A1 = Papercraft.html { a 'foo', href: '/' }

  def test_that_tag_method_accepts_papercraft_argument
    t1 = Papercraft.html {
      p A1
    }
    assert_equal(
      '<p><a href="/">foo</a></p>',
      t1.render
    )

    assert_equal(
      '<p><a href="/">foo</a></p>',
      C { p A1 }.render
    )
  end

  def test_that_tag_method_accepts_block
    assert_equal(
      '<div><p><a href="/">foo</a></p></div>',
      C { div { p { a 'foo', href: '/' } } }.render
    )
  end

  def __baz__; 'baz!'; end
  A2 = 'boo'

  def test_text
    t = Papercraft.html {
      text 'foo&bar'
      text __baz__
      text A2
    }

    c = t.compile
    expected = <<~RUBY.chomp
      ->(__buffer__, &__block__) do
        __buffer__ << "foo&amp;bar"
        __buffer__ << CGI.escapeHTML((__baz__).to_s)
        __buffer__ << "boo"
        __buffer__
      end
    RUBY
    assert_equal expected, c.to_code

    assert_equal 'foo&amp;barbaz!boo', c.to_proc.render
  end

  A3 = 'bar&baz'

  def test_emit_string
    assert_equal(
      '<p>foo</p>bar',
      C { p 'foo' ; emit 'bar' }.render
    )

    assert_equal(
      'bar&baz',
      C { emit A3 }.render
    )

    assert_equal(
      'baz!',
      C { emit __baz__ }.render
    )
  end

  def test_emit_template
    assert_equal(
      '<a href="/">foo</a>',
      C { emit A1 }.render
    )
  end
end

class CompilerSyntaxTest < Minitest::Test
  def template_body(body)
    body.chomp.lines.map { |l| "  #{l}" }.join
  end

  def test_compiler_syntax_case
    t = C { |x|
      case x
      when :foo
        h1 'foo'
      when :bar, :baz
        h2 'barbaz'
      else
        p 'noloso'
      end
    }

    assert_equal '<h1>foo</h1>', t.render(:foo)
    assert_equal '<h2>barbaz</h2>', t.render(:bar)
    assert_equal '<h2>barbaz</h2>', t.render(:baz)
    assert_equal '<p>noloso</p>', t.render(:bbb)
  end

  def test_empty_template
    t = C { }
    assert_equal '', t.render
  end

  def test_compiler_syntax_tag_content_expr
    t = c {
      p (1 + 2)
    }

    expected = <<~RUBY
      __buffer__ << "<p>\#{CGI.escapeHTML((1 + 2).to_s)}</p>"
    RUBY
    assert_equal template_body(expected), t.code_buffer.chomp

    assert_equal '<p>3</p>', t.to_proc.render
  end

  def test_compiler_syntax_tag_content_var
    foo = 42
    t = c {
      p foo
    }

    expected = <<~RUBY
      __buffer__ << "<p>\#{CGI.escapeHTML((foo).to_s)}</p>"
    RUBY
    assert_equal template_body(expected), t.code_buffer.chomp
    assert_equal '<p>42</p>', t.to_proc.render
  end

  FOO = 43

  def test_compiler_syntax_tag_content_const
    t = c {
      p FOO
    }

    expected = <<~RUBY
      __buffer__ << "<p>43</p>"
    RUBY
    assert_equal template_body(expected), t.code_buffer.chomp
    assert_equal '<p>43</p>', t.to_proc.render
  end

  def test_compiler_syntax_method_chain
    t = c {
      1.next.next.next
      p 2.next.next.next
    }

    expected = <<~RUBY
      1.next.next.next
      __buffer__ << "<p>\#{CGI.escapeHTML((2.next.next.next).to_s)}</p>"
    RUBY
    assert_equal template_body(expected), t.code_buffer.chomp
    assert_equal '<p>5</p>', t.to_proc.render
  end

  def test_compiler_syntax_ivar
    @foo = 'bar'

    t = c {
      p @foo
    }

    expected = <<~RUBY
      __buffer__ << "<p>\#{CGI.escapeHTML((@foo).to_s)}</p>"
    RUBY
    assert_equal template_body(expected), t.code_buffer.chomp
    assert_equal '<p>bar</p>', t.to_proc.render
  end

  def test_compiler_syntax_sub_template_with_args
    sub = ->(x) {
      p x
    }
    t = c {
      div {
        emit sub, 40 + 2
      }
    }

    expected = <<~RUBY
      __buffer__ << "<div>"
      Papercraft.__emit__(sub, __buffer__, 40 + 2)
      __buffer__ << "</div>"
    RUBY
    assert_equal template_body(expected), t.code_buffer.chomp
    assert_equal '<div><p>42</p></div>', t.to_proc.render
  end

  T1 = ->() { div { emit_yield } }

  def test_compiler_syntax_emit_yield
    t = c {
      emit(T1) {
        p 'foo'
      }
    }

    expected = <<~RUBY
      __sub_templates__[0].(__buffer__) {
        __buffer__ << \"<p>foo</p>\"
      }
    RUBY
    assert_equal template_body(expected), t.code_buffer.chomp
    assert_equal '<div><p>foo</p></div>', t.to_proc.render
  end
end
