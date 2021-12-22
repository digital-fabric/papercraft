# frozen_string_literal: true

require 'bundler/setup'
require 'minitest/autorun'
require 'papercraft'

class EntryPointTest < MiniTest::Test
  def test_that_entry_point_creates_new_instance
    block = proc { :foo }
    h = H(&block)

    assert_kind_of(Papercraft::Component, h)
    assert_equal :foo, h.call
  end
end

class RenderTest < MiniTest::Test
  def test_that_render_returns_rendered_html
    h = H { div { p 'foo'; p 'bar' } }
    assert_equal(
      '<div><p>foo</p><p>bar</p></div>',
      h.render
    )
  end
end

class AttributesTest < MiniTest::Test
  def test_that_attributes_are_supported_and_escaped
    assert_equal(
      '<div class="blue and green"/>',
      H { div class: 'blue and green' }.render
    )

    assert_equal(
      '<div onclick="return doit();"/>',
      H { div onclick: 'return doit();' }.render
    )

    assert_equal(
      '<a href="/?q=a%20b"/>',
      H { a href: '/?q=a b' }.render
    )
  end

  def test_that_valueless_attributes_are_supported
    assert_equal(
      '<input type="checkbox" checked/>',
      H { input type: 'checkbox', checked: true }.render
    )

    assert_equal(
      '<input type="checkbox"/>',
      H { input type: 'checkbox', checked: false }.render
    )
  end
end

class TagsTest < MiniTest::Test
  def test_that_tag_method_accepts_no_arguments
    assert_equal(
      '<div/>',
      H { div() }.render
    )
  end

  def test_that_tag_method_accepts_text_argument
    assert_equal(
      '<p>lorem ipsum</p>',
      H { p "lorem ipsum" }.render
    )
  end

  def test_that_tag_method_accepts_non_string_text_argument
    assert_equal(
      '<p>lorem</p>',
      H { p :lorem }.render
    )
  end

  def test_that_tag_method_escapes_string_text_argument
    assert_equal(
      '<p>lorem &amp; ipsum</p>',
      H { p 'lorem & ipsum' }.render
    )
  end

  def test_tag_underscore_to_hyphen_conversion
    assert_equal(
      '<my-nifty-tag>foo</my-nifty-tag>',
      H { my_nifty_tag 'foo' }.render
    )

    assert_equal(
      '<my-nifty-tag/>',
      H { my_nifty_tag }.render
    )
  end

  def test_that_tag_method_accepts_text_and_attributes
    assert_equal(
      '<p class="hi">lorem ipsum</p>',
      H { p "lorem ipsum", class: 'hi' }.render
    )
  end

  def test_attribute_underscore_to_hyphen_conversion
    assert_equal(
      '<p data-foo="bar">hello</p>',
      H { p 'hello', data_foo: 'bar' }.render
    )
  end

  def test_that_tag_method_accepts_papercraft_argument
    a = H { a 'foo', href: '/' }

    assert_equal(
      '<p><a href="/">foo</a></p>',
      H { p a }.render
    )
  end

  def test_that_tag_method_accepts_block
    assert_equal(
      '<div><p><a/></p></div>',
      H { div { p { a() } } }.render
    )
  end
end

class EmitTest < MiniTest::Test
  def test_that_emit_accepts_block
    # papercraft emits the value returned from the block
    block = proc { emit 'foobar' }

    assert_equal(
      'foobar',
      H { emit block }.render
    )
  end

  def test_that_emit_accepts_papercraft
    r = H { p 'foobar' }

    assert_equal(
      '<div><p>foobar</p></div>',
      H { div { emit r} }.render
    )
  end

  def test_that_emit_accepts_string
    assert_equal(
      '<div>foobar</div>',
      H { div { emit 'foobar' } }.render
    )
  end

  def test_that_emit_doesnt_escape_string
    assert_equal(
      '<div>foo&bar</div>',
      H { div { emit 'foo&bar' } }.render
    )
  end

  def test_that_e_is_alias_to_emit
    r = H { p 'foobar' }

    assert_equal(
      '<div><p>foobar</p></div>',
      H { div { e r} }.render
    )
  end

  def test_emit_yield
    r = H { body { emit_yield } }
    assert_raises { r.render(foo: 'bar') }

    assert_equal(
      '<body><p>foo</p><hr/></body>',
      r.render { p 'foo'; hr; }
    )
  end

  def test_emit_yield_with_sub_template
    outer = H { body { div(id: 'content') { emit_yield } } }
    inner = H { p 'foo' }
    assert_equal(
      '<body><div id="content"><p>foo</p></div></body>',
      outer.render(&inner)
    )
  end
end

class ScopeTest < MiniTest::Test
  def test_that_template_block_has_access_to_local_variables
    text = 'foobar'
    assert_equal(
      '<p>foobar</p>',
      H { p text }.render
    )
  end
end

class HTMLTest < MiniTest::Test
  def test_html5
    assert_equal(
      '<!DOCTYPE html><html><div><h1>foobar</h1></div></html>',
      H { html5 { div { h1 'foobar' } } }.render
    )
  end

  def test_link_stylesheet
    html = H {
      link_stylesheet '/assets/style.css'
    }
    assert_equal(
      '<link rel="stylesheet" href="/assets/style.css"/>',
      html.render
    )

    html = H {
      link_stylesheet '/assets/style.css', media: 'print'
    }
    assert_equal(
      '<link media="print" rel="stylesheet" href="/assets/style.css"/>',
      html.render
    )
  end

  def test_style
    html = H {
      style <<~CSS.chomp
        * { color: red }
      CSS
    }
    assert_equal(
      '<style>* { color: red }</style>',
      html.render
    )
  end

  def test_html_encoding
    html = H {
      span 'me, myself & I'
    }

    assert_equal(
      '<span>me, myself &amp; I</span>',
      html.render
    )
  end
end

class XMLTest < MiniTest::Test
  def test_generic_xml
    xml = X {
      rss(version: '2.0') {
        channel {
          item 'foo'
          item 'bar'
        }
      }
    }

    assert_equal(
      '<rss version="2.0"><channel><item>foo</item><item>bar</item></channel></rss>',
      xml.render
    )
  end

  def test_xml_encoding
    xml = X {
      link 'http://liftoff.msfc.nasa.gov/news/2003/news-starcity.asp'
    }

    assert_equal(
      '<link>http://liftoff.msfc.nasa.gov/news/2003/news-starcity.asp</link>',
      xml.render
    )
  end
end
