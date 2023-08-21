# frozen_string_literal: true

require 'bundler/setup'
require 'minitest/autorun'
require 'papercraft'

class JsonTest < Minitest::Test
  def test_json_method_with_block
    block = proc { :foo }
    j = Papercraft.json(&block)

    assert_kind_of(Papercraft::Template, j)
    assert_equal :json, j.mode
    assert_equal :foo, j.call
  end

  def test_json_method_with_argument
    o = proc { :foo }
    j = Papercraft.json(o)

    assert_kind_of(Papercraft::Template, j)
    assert_equal :json, j.mode
    assert_equal :foo, j.call

    j2 = Papercraft.json(j)
    assert_equal j2, j
  end

  def test_json_array
    json = Papercraft.json {
      item 1
      item 'a'
      item nil
      item true
      item false
      item 2.1
      item {
        foo 'bar'
      }
    }

    assert_equal(
      '[1,"a",null,true,false,2.1,{"foo":"bar"}]',
      json.render
    )
  end

  def test_json_nested_objects
    json = Papercraft.json {
      foo {
        bar {
          item 'a'
          item 'b'
          item {
            t1 'abc'
            t2 'def'
          }
          item 1
          item 2
          item {
            item {
              item 3
            }
          }
        }
      }
    }
    assert_equal(
      '{"foo":{"bar":["a","b",{"t1":"abc","t2":"def"},1,2,[[3]]]}}',
      json.render
    )
  end

  def test_mixing_array_and_hash_items
    assert_raises {
      Papercraft.json { foo 'bar'; item 1 }.render
    }

    assert_raises {
      Papercraft.json {
        foo {
          item 1
          bar 'baz'
        }
      }.render
    }
  end

  def test_json_template_params
    json = Papercraft.json { |bar:|
      foo bar
    }

    assert_equal '{"foo":42}', json.render(bar: 42)
  end

  def test_json_template_application
    json = Papercraft.json { |bar:|
      foo bar
    }
    j2 = json.apply(bar: 42)
    assert_equal '{"foo":42}', j2.render
  end

  def test_json_template_with_iteration
    data = [1, 2, 3]

    json = Papercraft.json {
      item(_for: data) { |d| foo d }
    }

    assert_equal '[{"foo":1},{"foo":2},{"foo":3}]', json.render
  end
end
