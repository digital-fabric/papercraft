# frozen_string_literal: true

require 'bundler/setup'
require 'minitest/autorun'
require 'papercraft'

class PapercraftRenderTest < Minitest::Test
  def test_papercraft_render_with_block
    html = Papercraft.render {
      h1 "foo"
    }
    assert_equal '<h1>foo</h1>', html
  end

  def test_papercraft_render_with_template
    t = -> {
      h1 "foo"
    }
    html = Papercraft.render(t)    
    assert_equal '<h1>foo</h1>', html
  end

  def test_papercraft_render_template_with_parameters
    t = ->(name) {
      h1 name
    }
    html = Papercraft.render(t, 'bar')    
    assert_equal '<h1>bar</h1>', html

    t = ->(name:) {
      h1 name
    }
    assert_raises(ArgumentError) { Papercraft.render(t, 'bar') }
    html = Papercraft.render(t, name: 'bar')
    assert_equal '<h1>bar</h1>', html
  end

  def test_papercraft_render_template_with_block
    t = ->(name:) {
      div {
        render_yield(name:)
      }
    }
    assert_raises(LocalJumpError) { Papercraft.render(t, name: 'bar') }
    html = Papercraft.render(t, name: 'bar') { |name:| h2 name }
    assert_equal '<div><h2>bar</h2></div>', html 
  end

  def test_papercraft_render_xml
    t = ->(name:) {
      link name
    }
    xml = Papercraft.render_xml(t, name: 'foo')
    assert_equal '<link>foo</link>', xml

    xml = Papercraft.render_xml { link 'bar' }
    assert_equal '<link>bar</link>', xml
  end

  def test_papercraft_extension
    Papercraft.extension(
      __foo_bar__: -> { h1 "foobar" }
    )
    html = Papercraft.render { __foo_bar__ }
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
end
