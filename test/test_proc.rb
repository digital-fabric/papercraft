# frozen_string_literal: true

require_relative './helper'
require 'papercraft/proc'

class ProcAPITest < Minitest::Test
  def test_proc_ast
    t = -> { h1 'foo' }
    assert_kind_of Prism::Node, t.ast
    assert_equal Papercraft.ast(t).inspect, t.ast.inspect
  end

  def test_proc_compiled_code
    t = -> { h1 'foo' }
    assert_equal Papercraft.compiled_code(t), t.compiled_code
  end

  def test_proc_to_html
    t = ->(x) { h1 x }
    assert_equal Papercraft.html(t, 'foo'), t.to_html('foo')
  end

  def test_proc_to_xml
    t = ->(x) { link x }
    assert_equal Papercraft.xml(t, 'foo'), t.to_xml('foo')
  end

  def test_proc_apply
    t = ->(x) { h1 x }
    t2 = t.apply('foo')

    assert_equal %(<h1>foo</h1>), t2.to_html
  end
end
