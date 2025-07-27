# frozen_string_literal: true

require 'bundler/setup'
require 'minitest/autorun'
require 'tilt/papercraft'

class TiltIntegrationTest < Minitest::Test
  def test_extension
    assert_equal Tilt::PapercraftTemplate, Tilt['papercraft']
  end

  def test_tilt_inline_template
    t = Tilt['papercraft'].new {
      "
        h1 'foo'
        p 'bar'
      "
    }

    html = t.render
    assert_equal '<h1>foo</h1><p>bar</p>', html
  end

  def test_tilt_inline_template_with_scope
    t = Tilt['papercraft'].new {
      "
        h1 scope.foo
      "
    }

    def foo
      'bar'
    end

    html = t.render(self)
    assert_equal '<h1>bar</h1>', html
  end

  def test_tilt_inline_template_with_locals
    t = Tilt['papercraft'].new {
      "
        h1 locals[:a]
        p locals[:b]
        emit block if block
      "
    }

    html = t.render(Object.new, a: 42, b: 'abc')
    assert_equal '<h1>42</h1><p>abc</p>', html
  end

  def test_tilt_inline_template_with_block
    t = Tilt['papercraft'].new {
      "
        h1 locals[:a]
        p locals[:b]
        emit block if block
      "
    }

    html = t.render(Object.new, a: 'foo', b: 'bar') { hr }
    assert_equal '<h1>foo</h1><p>bar</p><hr>', html
  end
end
