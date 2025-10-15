# frozen_string_literal: true

require 'bundler/setup'
require 'minitest/autorun'
require 'papercraft'

class HtmlTest < Minitest::Test
  def test_void_elements
    h = -> {
      hr
      input value: 'foo'
      br
      text 'hi'
      hr
    }
    assert_equal '<hr><input value="foo"><br>hi<hr>', Papercraft.render(h)
  end

  def test_error_on_void_elements_with_block
    t = -> {
      hr { foo }
    }
    assert_raises(Papercraft::Error) { Papercraft.render(t) }
    
    t = -> {
      input "foo"
    }
    assert_raises(Papercraft::Error) { Papercraft.render(t) }
  end

  def test_html5
    assert_equal(
      '<!DOCTYPE html><html><div><h1>foobar</h1></div></html>',
      Papercraft.render(-> { html5 { div { h1 'foobar' } } })
    )
  end

  def test_html
    assert_equal(
      '<!DOCTYPE html><html><div><h1>foobar</h1></div></html>',
      Papercraft.render(-> { html { div { h1 'foobar' } } })
    )
  end

  def test_html_with_lang
    assert_equal(
      '<!DOCTYPE html><html lang="en"><div><h1>foobar</h1></div></html>',
      Papercraft.render(-> { html(lang: "en") { div { h1 'foobar' } } })
    )
  end

  def test_link_stylesheet
    html = -> {
      link_stylesheet '/assets/style.css'
    }
    assert_equal(
      '<link rel="stylesheet" href="/assets/style.css">',
      Papercraft.render(html)
    )

    html = -> {
      link_stylesheet '/assets/style.css', media: 'print'
    }
    assert_equal(
      '<link rel="stylesheet" href="/assets/style.css" media="print">',
      Papercraft.render(html)
    )
  end

  def test_style
    html = -> {
      style <<~CSS.chomp
        * { color: red }
        a & b { color: green }
      CSS
    }
    assert_equal(
      "<style>* { color: red }\na & b { color: green }</style>",
      Papercraft.render(html)
    )
  end

  def test_script
    html = -> {
      script <<~JS.chomp
        if (a && b) c();
      JS
    }
    assert_equal(
      "<script>if (a && b) c();</script>",
      Papercraft.render(html)
    )
  end

  def test_empty_script
    html = -> {
      script src: '/static/stuff.js'
    }
    assert_equal(
      "<script src=\"/static/stuff.js\"></script>",
      Papercraft.render(html)
    )
  end

  def test_html_encoding
    html = -> {
      span 'me, myself & I'
    }

    assert_equal(
      '<span>me, myself &amp; I</span>',
      Papercraft.render(html)
    )
  end
end

class RenderTest < Minitest::Test
  def test_that_render_returns_rendered_html
    h = -> { div { p 'foo'; p 'bar' } }
    assert_equal(
      '<div><p>foo</p><p>bar</p></div>',
      Papercraft.render(h)
    )
  end
end

class AttributesTest < Minitest::Test
  def test_attribute_encoding
    assert_equal(
      '<div class="blue and green"></div>',
      Papercraft.render(-> { div class: 'blue and green' })
    )

    assert_equal(
      '<div onclick="return doit();"></div>',
      Papercraft.render(-> { div onclick: 'return doit();' })
    )

    assert_equal(
      '<a href="/?q=a b"></a>',
      Papercraft.render(-> { a href: '/?q=a b' })
    )
  end

  def test_valueless_attributes
    assert_equal(
      '<input type="checkbox" checked>',
      Papercraft.render(-> { input type: 'checkbox', checked: true })
    )

    assert_equal(
      '<input type="checkbox">',
      Papercraft.render(-> { input type: 'checkbox', checked: false })
    )
  end

  def test_array_attributes
    assert_equal(
      '<div class="foo bar"></div>',
      Papercraft.render(-> { div class: [:foo, :bar] })
    )

    assert_equal(
      '<div class="foo  bar"></div>',
      Papercraft.render(-> { div class: [:foo, nil, 'bar'] })
    )
  end
end

class DynamicTagMethodTest < Minitest::Test
  def test_that_dynamic_tag_method_accepts_no_arguments
    assert_equal(
      '<div></div>',
      Papercraft.render(-> { div() })
    )
  end

  def test_that_dynamic_tag_method_accepts_text_argument
    assert_equal(
      '<p>lorem ipsum</p>',
      Papercraft.render(-> { p "lorem ipsum" })
    )
  end

  def test_that_dynamic_tag_method_accepts_non_string_text_argument
    assert_equal(
      '<p>lorem</p>',
      Papercraft.render(-> { p :lorem })
    )
  end

  def test_that_dynamic_tag_method_escapes_string_text_argument
    assert_equal(
      '<p>lorem &amp; ipsum</p>',
      Papercraft.render(-> { p 'lorem & ipsum' })
    )
  end

  def test_dynamic_tag_underscore_to_hyphen_conversion
    assert_equal(
      '<my-nifty-tag>foo</my-nifty-tag>',
      Papercraft.render(-> { my_nifty_tag 'foo' })
    )

    assert_equal(
      '<my-nifty-tag></my-nifty-tag>',
      Papercraft.render(-> { my_nifty_tag })
    )
  end

  def test_that_dynamic_tag_method_accepts_text_and_attributes
    assert_equal(
      '<p class="hi">lorem ipsum</p>',
      Papercraft.render(-> { p "lorem ipsum", class: 'hi' })
    )
  end

  def test_dynamic_tag_attribute_underscore_to_hyphen_conversion
    assert_equal(
      '<p data-foo="bar">hello</p>',
      Papercraft.render(-> { p 'hello', data_foo: 'bar' })
    )
  end

  def test_that_dynamic_tag_method_accepts_papercraft_argument
    a = -> { a 'foo', href: '/' }

    assert_equal(
      '<p><a href="/">foo</a></p>',
      Papercraft.render(-> { p(&a) })
    )
  end

  def test_that_dynamic_tag_method_accepts_block
    assert_equal(
      '<div><p><a></a></p></div>',
      Papercraft.render(-> { div { p { a() } } })
    )
  end
end

class TagMethodTest < Minitest::Test
  def test_that_tag_method_accepts_no_arguments
    assert_equal(
      '<div></div>',
      Papercraft.render(-> { tag(:div) })
    )
  end

  def test_that_tag_method_accepts_text_argument
    assert_equal(
      '<p>lorem ipsum</p>',
      Papercraft.render(-> { tag :p, "lorem ipsum" })
    )
  end

  def test_that_tag_method_accepts_non_string_text_argument
    assert_equal(
      '<p>lorem</p>',
      Papercraft.render(-> { tag :p, :lorem })
    )
  end

  def test_that_tag_method_escapes_string_text_argument
    assert_equal(
      '<p>lorem &amp; ipsum</p>',
      Papercraft.render(-> { tag :p, 'lorem & ipsum' })
    )
  end

  def test_tag_underscore_to_hyphen_conversion
    assert_equal(
      '<my-nifty-tag>foo</my-nifty-tag>',
      Papercraft.render(-> { tag :my_nifty_tag, 'foo' })
    )

    assert_equal(
      '<my-nifty-tag></my-nifty-tag>',
      Papercraft.render(-> { tag :my_nifty_tag })
    )
  end

  def test_that_tag_method_accepts_text_and_attributes
    assert_equal(
      '<p class="hi">lorem ipsum</p>',
      Papercraft.render(-> { tag :p, "lorem ipsum", class: 'hi' })
    )
  end

  def test_attribute_underscore_to_hyphen_conversion
    assert_equal(
      '<p data-foo="bar">hello</p>',
      Papercraft.render(-> { tag :p, 'hello', data_foo: 'bar' })
    )
  end

  def test_that_tag_method_accepts_papercraft_argument
    a = -> { tag :a, 'foo', href: '/' }

    assert_equal(
      '<p><a href="/">foo</a></p>',
      Papercraft.render(-> { tag :p, &a })
    )
  end

  def test_that_tag_method_accepts_block
    assert_equal(
      '<div><p><a></a></p></div>',
      Papercraft.render(-> { tag(:div) { tag(:p) { tag :a } } })
    )
  end
end


class SubTemplateTest < Minitest::Test
  def test_that_render_accepts_block
    block = proc { raw 'foobar' }

    assert_equal(
      'foobar',
      Papercraft.render(-> { render block })
    )
  end

  def test_that_raw_accepts_string
    assert_equal(
      '<div>foobar</div>',
      Papercraft.render(-> { div { raw 'foobar' } })
    )
  end

  def test_that_raw_doesnt_escape_string
    assert_equal(
      '<div>foo&bar</div>',
      Papercraft.render(-> { div { raw 'foo&bar' } })
    )
  end

  def test_render_yield
    r = -> { body { render_yield } }
    assert_raises { Papercraft.render(r, foo: 'bar') }

    assert_equal(
      '<body><p>foo</p><hr></body>',
      Papercraft.render(r) { p 'foo'; hr; }
    )
  end

  def test_render_yield_with_sub_template
    outer = -> { body { div(id: 'content') { render_yield } } }
    inner = -> { p 'foo' }
    assert_equal(
      '<body><div id="content"><p>foo</p></div></body>',
      Papercraft.render(outer, &inner)
    )
  end

  def test_render_yield_in_each_block
    ulist = ->(list) {
      ul {
        list.each { |item|
          li { render_yield item }
        }
      }
    }

    item_card = ->(item) {
      card {
        span item
      }
    }

    assert_equal '<ul><li><card><span>foo</span></card></li><li><card><span>bar</span></card></li></ul>',
      Papercraft.render(ulist, %w{foo bar}, &item_card)
  end
end

class ScopeTest < Minitest::Test
  def test_that_template_block_has_access_to_local_variables
    text = 'foobar'
    assert_equal(
      '<p>foobar</p>',
      Papercraft.render(-> { p text })
    )
  end
end

class DeferTest < Minitest::Test
  def test_defer
    buffer = []

    html = -> {
      div {
        buffer << :before
        defer {
          buffer << :defer_block
          h1 @foo
        }
        @foo = 'bar'
      }
    }

    assert_equal "<div><h1>bar</h1></div>", Papercraft.render(html)
  end

  def test_deferred_title
    layout = -> {
      html {
        head {
          defer {
            title @title
          }
        }
        body { render_yield }
      }
    }

    html = Papercraft.render(layout) {
      @title = 'My super page'
      h1 'foo'
    }

    assert_equal "<!DOCTYPE html><html><head><title>My super page</title></head><body><h1>foo</h1></body></html>",
      html
  end

  def test_multiple_defer
    layout = -> {
      html {
        head {
          defer { title @title }
        }
        body { render_yield }
      }
    }
    form = -> {
      form {
        defer {
          h3 @error_message if @error_message
        }
        render_yield
      }
    }

    user_form = Papercraft.apply(form) {
      @title = 'Awesome user form'
      @error_message = 'Syntax error!'

      p 'Welcome to the awesome user form'
    }

    html = Papercraft.render(layout, &user_form)

    assert_equal "<!DOCTYPE html><html><head><title>Awesome user form</title></head><body><form><h3>Syntax error!</h3><p>Welcome to the awesome user form</p></form></body></html>",
      html
  end
end
