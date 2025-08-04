# frozen_string_literal: true

require 'bundler/setup'
require 'minitest/autorun'
require 'p2'

class HtmlTest < Minitest::Test
  def test_html_method_with_block
    block = proc { :foo }
    h = P2.html(&block)

    assert_kind_of(P2::Template, h)
    assert_equal :foo, h.call
  end

  def test_html_method_with_argument
    o = proc { :foo }
    h = P2.html(o)

    assert_kind_of(P2::Template, h)
    assert_equal :foo, h.call

    h2 = P2.html(h)
    assert_equal h2, h
  end

  def test_void_elements
    h = P2.html {
      hr
      input value: 'foo'
      br
      text 'hi'
      hr
    }
    assert_equal '<hr><input value="foo"><br>hi<hr>', h.render
  end

  def test_html5
    assert_equal(
      '<!DOCTYPE html><html><div><h1>foobar</h1></div></html>',
      P2.html { html5 { div { h1 'foobar' } } }.render
    )
  end

  def test_link_stylesheet
    html = P2.html {
      link_stylesheet '/assets/style.css'
    }
    assert_equal(
      '<link rel="stylesheet" href="/assets/style.css">',
      html.render
    )

    html = P2.html {
      link_stylesheet '/assets/style.css', media: 'print'
    }
    assert_equal(
      '<link media="print" rel="stylesheet" href="/assets/style.css">',
      html.render
    )
  end

  def test_style
    html = P2.html {
      style <<~CSS.chomp
        * { color: red }
        a & b { color: green }
      CSS
    }
    assert_equal(
      "<style>* { color: red }\na & b { color: green }</style>",
      html.render
    )
  end

  def test_script
    html = P2.html {
      script <<~JS.chomp
        if (a && b) c();
      JS
    }
    assert_equal(
      "<script>if (a && b) c();</script>",
      html.render
    )
  end

  def test_empty_script
    html = P2.html {
      script src: '/static/stuff.js'
    }
    assert_equal(
      "<script src=\"/static/stuff.js\"></script>",
      html.render
    )
  end

  def test_html_encoding
    html = P2.html {
      span 'me, myself & I'
    }

    assert_equal(
      '<span>me, myself &amp; I</span>',
      html.render
    )
  end

  def test_import_map_hash
    html = P2.html {
      import_map(a: '/foo/a.js', b: '/bar/b.js')
    }

    assert_equal(
      '<script type="importmap">{"a":"/foo/a.js","b":"/bar/b.js"}</script>',
      html.render
    )
  end

  def calc_versioned_js_file_url(name)
    stat = File.stat(File.join(__dir__, 'js', name))
    "/static/js/#{name}?v=#{stat.mtime.to_i}"
  end

  def test_import_map_path
    html = P2.html {
      import_map(File.join(__dir__, 'js'), '/static/js')
    }

    foo_url = calc_versioned_js_file_url('foo.js')
    bar_url = calc_versioned_js_file_url('bar.js')

    expected_map = { 'bar' => bar_url, 'foo' => foo_url }

    assert_equal(
      "<script type=\"importmap\">#{expected_map.to_json}</script>",
      html.render
    )
  end

  def test_js_module
    html = P2.html {
      js_module 'foo( );'
    }

    assert_equal(
      '<script type="module">foo( );</script>',
      html.render
    )
  end
end

class RenderTest < Minitest::Test
  def test_that_render_returns_rendered_html
    h = P2.html { div { p 'foo'; p 'bar' } }
    assert_equal(
      '<div><p>foo</p><p>bar</p></div>',
      h.render
    )
  end
end

class AttributesTest < Minitest::Test
  def test_attribute_encoding
    assert_equal(
      '<div class="blue and green"></div>',
      P2.html { div class: 'blue and green' }.render
    )

    assert_equal(
      '<div onclick="return doit();"></div>',
      P2.html { div onclick: 'return doit();' }.render
    )

    assert_equal(
      '<a href="/?q=a b"></a>',
      P2.html { a href: '/?q=a b' }.render
    )
  end

  def test_valueless_attributes
    assert_equal(
      '<input type="checkbox" checked>',
      P2.html { input type: 'checkbox', checked: true }.render
    )

    assert_equal(
      '<input type="checkbox">',
      P2.html { input type: 'checkbox', checked: false }.render
    )
  end

  def test_array_attributes
    assert_equal(
      '<div class="foo bar"></div>',
      P2.html { div class: [:foo, :bar] }.render
    )

    assert_equal(
      '<div class="foo  bar"></div>',
      P2.html { div class: [:foo, nil, 'bar'] }.render
    )
  end
end

class DynamicTagMethodTest < Minitest::Test
  def test_that_dynamic_tag_method_accepts_no_arguments
    assert_equal(
      '<div></div>',
      P2.html { div() }.render
    )
  end

  def test_that_dynamic_tag_method_accepts_text_argument
    assert_equal(
      '<p>lorem ipsum</p>',
      P2.html { p "lorem ipsum" }.render
    )
  end

  def test_that_dynamic_tag_method_accepts_non_string_text_argument
    assert_equal(
      '<p>lorem</p>',
      P2.html { p :lorem }.render
    )
  end

  def test_that_dynamic_tag_method_escapes_string_text_argument
    assert_equal(
      '<p>lorem &amp; ipsum</p>',
      P2.html { p 'lorem & ipsum' }.render
    )
  end

  def test_dynamic_tag_underscore_to_hyphen_conversion
    assert_equal(
      '<my-nifty-tag>foo</my-nifty-tag>',
      P2.html { my_nifty_tag 'foo' }.render
    )

    assert_equal(
      '<my-nifty-tag></my-nifty-tag>',
      P2.html { my_nifty_tag }.render
    )
  end

  def test_that_dynamic_tag_method_accepts_text_and_attributes
    assert_equal(
      '<p class="hi">lorem ipsum</p>',
      P2.html { p "lorem ipsum", class: 'hi' }.render
    )
  end

  def test_dynamic_tag_attribute_underscore_to_hyphen_conversion
    assert_equal(
      '<p data-foo="bar">hello</p>',
      P2.html { p 'hello', data_foo: 'bar' }.render
    )
  end

  def test_that_dynamic_tag_method_accepts_p2_argument
    a = P2.html { a 'foo', href: '/' }

    assert_equal(
      '<p><a href="/">foo</a></p>',
      P2.html { p a }.render
    )
  end

  def test_that_dynamic_tag_method_accepts_block
    assert_equal(
      '<div><p><a></a></p></div>',
      P2.html { div { p { a() } } }.render
    )
  end
end

class TagMethodTest < Minitest::Test
  def test_that_tag_method_accepts_no_arguments
    assert_equal(
      '<div></div>',
      P2.html { tag(:div) }.render
    )
  end

  def test_that_tag_method_accepts_text_argument
    assert_equal(
      '<p>lorem ipsum</p>',
      P2.html { tag :p, "lorem ipsum" }.render
    )
  end

  def test_that_tag_method_accepts_non_string_text_argument
    assert_equal(
      '<p>lorem</p>',
      P2.html { tag :p, :lorem }.render
    )
  end

  def test_that_tag_method_escapes_string_text_argument
    assert_equal(
      '<p>lorem &amp; ipsum</p>',
      P2.html { tag :p, 'lorem & ipsum' }.render
    )
  end

  def test_tag_underscore_to_hyphen_conversion
    assert_equal(
      '<my-nifty-tag>foo</my-nifty-tag>',
      P2.html { tag :my_nifty_tag, 'foo' }.render
    )

    assert_equal(
      '<my-nifty-tag></my-nifty-tag>',
      P2.html { tag :my_nifty_tag }.render
    )
  end

  def test_that_tag_method_accepts_text_and_attributes
    assert_equal(
      '<p class="hi">lorem ipsum</p>',
      P2.html { tag :p, "lorem ipsum", class: 'hi' }.render
    )
  end

  def test_attribute_underscore_to_hyphen_conversion
    assert_equal(
      '<p data-foo="bar">hello</p>',
      P2.html { tag :p, 'hello', data_foo: 'bar' }.render
    )
  end

  def test_that_tag_method_accepts_p2_argument
    a = P2.html { tag :a, 'foo', href: '/' }

    assert_equal(
      '<p><a href="/">foo</a></p>',
      P2.html { tag :p, a }.render
    )
  end

  def test_that_tag_method_accepts_block
    assert_equal(
      '<div><p><a></a></p></div>',
      P2.html { tag(:div) { tag(:p) { tag :a } } }.render
    )
  end
end


class EmitTest < Minitest::Test
  def test_that_emit_accepts_block
    # p2 emits the value returned from the block
    block = proc { emit 'foobar' }

    assert_equal(
      'foobar',
      P2.html { emit block }.render
    )
  end

  def test_that_emit_accepts_p2
    r = P2.html { p 'foobar' }

    assert_equal(
      '<div><p>foobar</p></div>',
      P2.html { div { emit r} }.render
    )
  end

  def test_that_emit_accepts_string
    assert_equal(
      '<div>foobar</div>',
      P2.html { div { emit 'foobar' } }.render
    )
  end

  def test_that_emit_doesnt_escape_string
    assert_equal(
      '<div>foo&bar</div>',
      P2.html { div { emit 'foo&bar' } }.render
    )
  end

  def test_that_e_is_alias_to_emit
    r = P2.html { p 'foobar' }

    assert_equal(
      '<div><p>foobar</p></div>',
      P2.html { div { e r} }.render
    )
  end

  def test_emit_yield
    r = P2.html { body { emit_yield } }
    assert_raises { r.render(foo: 'bar') }

    assert_equal(
      '<body><p>foo</p><hr></body>',
      r.render { p 'foo'; hr; }
    )
  end

  def test_emit_yield_with_sub_template
    outer = P2.html { body { div(id: 'content') { emit_yield } } }
    inner = P2.html { p 'foo' }
    assert_equal(
      '<body><div id="content"><p>foo</p></div></body>',
      outer.render(&inner)
    )
  end

  def test_emit_yield_syntropy
    c = Class.new
    layout = c.module_eval "P2.html { |**a|
      body { emit_yield(**a) }
    }"

    body = layout.apply {
      h1 'bar'
    }

    html = body.render

    assert_equal '<body><h1>bar</h1></body>', html
  end
end

class ScopeTest < Minitest::Test
  def test_that_template_block_has_access_to_local_variables
    text = 'foobar'
    assert_equal(
      '<p>foobar</p>',
      P2.html { p text }.render
    )
  end
end

class DeferTest < Minitest::Test
  def test_defer
    buffer = []

    html = P2.html {
      div {
        buffer << :before
        defer {
          buffer << :defer_block
          h1 @foo
        }
        @foo = 'bar'
      }
    }

    assert_equal "<div><h1>bar</h1></div>", html.render
  end

  def test_deferred_title
    layout = P2.html {
      html {
        head {
          defer {
            title @title
          }
        }
        body { emit_yield }
      }
    }

    html = layout.render {
      @title = 'My super page'
      h1 'foo'
    }

    assert_equal "<html><head><title>My super page</title></head><body><h1>foo</h1></body></html>",
      html
  end

  def test_multiple_defer
    layout = P2.html {
      html {
        head {
          defer { title @title }
        }
        body { emit_yield }
      }
    }
    form = P2.html {
      form {
        defer {
          h3 @error_message if @error_message
        }
        emit_yield
      }
    }

    user_form = form.apply {
      @title = 'Awesome user form'
      @error_message = 'Syntax error!'

      p 'Welcome to the awesome user form'
    }

    html = layout.render(&user_form)

    assert_equal "<html><head><title>Awesome user form</title></head><body><form><h3>Syntax error!</h3><p>Welcome to the awesome user form</p></form></body></html>",
      html
  end

  def test_nested_defer
    layout = P2.html { |foo, bar|
      h1 'foo'
      defer { emit foo }
      h1 'bar'
      defer { emit bar }

      @foo = 1
      @bar = 2
      @baz = 3
    }

    foo = P2.html {
      p 'foo'
      p @foo
      defer { p @baz }
      p 'nomorefoo'
    }

    bar = P2.html {
      p 'bar'
      p @bar
      p 'nomorebar'
    }

    assert_equal "<h1>foo</h1><p>foo</p><p>1</p><p>3</p><p>nomorefoo</p><h1>bar</h1><p>bar</p><p>2</p><p>nomorebar</p>", layout.render(foo, bar)
  end
end
