# frozen_string_literal: true

require_relative './helper'

class PapercraftRenderTest < Minitest::Test
  def test_papercraft_html_with_block
    html = Papercraft.html {
      h1 "foo"
    }
    assert_equal '<h1>foo</h1>', html
  end

  def test_papercraft_html_with_template
    t = -> {
      h1 "foo"
    }
    html = Papercraft.html(t)    
    assert_equal '<h1>foo</h1>', html
  end

  def test_papercraft_html_template_with_parameters
    t = ->(name) {
      h1 name
    }
    html = Papercraft.html(t, 'bar')    
    assert_equal '<h1>bar</h1>', html

    t = ->(name:) {
      h1 name
    }
    assert_raises(ArgumentError) { Papercraft.html(t, 'bar') }
    html = Papercraft.html(t, name: 'bar')
    assert_equal '<h1>bar</h1>', html
  end

  def test_papercraft_html_template_with_block
    t = ->(name:) {
      div {
        render_yield(name:)
      }
    }
    assert_raises(LocalJumpError) { Papercraft.html(t, name: 'bar') }
    html = Papercraft.html(t, name: 'bar') { |name:| h2 name }
    assert_equal '<div><h2>bar</h2></div>', html 
  end

  def test_papercraft_xml
    t = ->(name:) {
      link name
    }
    xml = Papercraft.xml(t, name: 'foo')
    assert_equal '<link>foo</link>', xml

    xml = Papercraft.xml { link 'bar' }
    assert_equal '<link>bar</link>', xml
  end

  def test_papercraft_extension
    Papercraft.extension(
      __foo_bar__: -> { h1 "foobar" }
    )
    html = Papercraft.html { __foo_bar__ }
    assert_equal '<h1>foobar</h1>', html
  end

  def test_papercraft_underscores_to_dashes
    assert_equal "abc-def", Papercraft.underscores_to_dashes("abc_def")
    assert_equal "abc-def", Papercraft.underscores_to_dashes(:abc_def)
  end

  def test_papercraft_format_tag_attrs
    assert_equal 'abc="def"', Papercraft.format_tag_attrs(abc: "def")
    assert_equal 'abc="def" ghi="jkl"', Papercraft.format_tag_attrs(
      abc: "def", ghi: "jkl"
    )
    assert_equal 'abc-def="ghi"', Papercraft.format_tag_attrs(
      abc_def: "ghi"
    )
    assert_equal 'abc="def" ghi', Papercraft.format_tag_attrs(
      abc: "def", ghi: true, jkl: false
    )
  end

  def test_papercraft_markdown_doc
    doc = Papercraft.markdown_doc("# foo")
    assert_kind_of Kramdown::Document, doc
  end

  def test_papercraft_markdown
    html = Papercraft.markdown("# foo")
    assert_equal '<h1 id="foo">foo</h1>', html.chomp
  end

  def test_papercraft_cache_html
    count = 0
    t = ->(name) {
      count += 1
      h1 name
    }

    assert_equal "<h1>foo</h1>", Papercraft.cache_html(t, 'foo', 'foo')
    assert_equal 1, count
    assert_equal "<h1>foo</h1>", Papercraft.cache_html(t, 'foo', 'foo')
    assert_equal 1, count

    assert_equal "<h1>foo</h1>", Papercraft.cache_html(t, 'foo', 'bar')
    assert_equal 1, count
    
    assert_equal "<h1>bar</h1>", Papercraft.cache_html(t, 'bar', 'bar')
    assert_equal 2, count
    assert_equal "<h1>bar</h1>", Papercraft.cache_html(t, 'bar', 'bar')
    assert_equal 2, count
  end

  def test_papercraft_cache_xml
    count = 0
    t = ->(name) {
      count += 1
      link name
    }

    assert_equal "<link>foo</link>", Papercraft.cache_xml(t, 'foo', 'foo')
    assert_equal 1, count
    assert_equal "<link>foo</link>", Papercraft.cache_xml(t, 'foo', 'foo')
    assert_equal 1, count

    assert_equal "<link>foo</link>", Papercraft.cache_xml(t, 'foo', 'bar')
    assert_equal 1, count
    
    assert_equal "<link>bar</link>", Papercraft.cache_xml(t, 'bar', 'bar')
    assert_equal 2, count
    assert_equal "<link>bar</link>", Papercraft.cache_xml(t, 'bar', 'bar')
    assert_equal 2, count
  end

  def test_papercraft_apply_params
    t = ->(a, b, c:, d:) {
      hr(a => b, c => d)
    }
    a = Papercraft.apply(t, 'foo', 'bar', c: 'baz', d: 42)
    assert_equal '<hr foo="bar" baz="42">', Papercraft.html(a)
  end

  def test_papercraft_apply_with_block
    t = ->(foo:) { div { render_yield(bar: foo) } }
    a = Papercraft.apply(t, foo: 'baz') { |bar:| h1 bar }
    assert_equal "<div><h1>baz</h1></div>", Papercraft.html(a)
  end

  def test_papercraft_apply_with_block_nested_render_yield
    t = ->(foo:) { div { render_yield(bar: foo) } }
    a = Papercraft.apply(t, foo: 'baz') { |**props| section { render_yield(**props) } }
    html = Papercraft.html(a) { |bar:| h1 bar }
    assert_equal "<div><section><h1>baz</h1></section></div>", html
  end

  def test_papercraft_apply_nested_render_yield
    t = ->(foo:) { div { render_yield(bar: foo) } }
    a = Papercraft.apply(t, foo: 'baz')
    html = Papercraft.html(a) { |bar:| h1 bar }
    assert_equal "<div><h1>baz</h1></div>", html
    
  end
end
