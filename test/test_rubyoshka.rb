require 'modulation'
require 'minitest/autorun'

H = import '../lib/rubyoshka'

class EntryPointTest < MiniTest::Test
  def test_that_entry_point_creates_new_instance
    block = proc { }
    h = H(&block)

    assert_kind_of(H, h)
    assert_equal(block, h.block)
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

  def test_that_tag_method_accepts_text_and_attributes
    assert_equal(
      '<p class="hi">lorem ipsum</p>',
      H { p "lorem ipsum", class: 'hi' }.render
    )
  end

  def test_that_tag_method_accepts_rubyoshka_argument
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
    # rubyoshka emits the value returned from the block
    block = proc { emit 'foobar' }
    
    assert_equal(
      'foobar',
      H { emit block }.render
    )
  end

  def test_that_emit_accepts_rubyoshka
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
end

class ComponentTest < MiniTest::Test
  H::C1 = H { article { h1 'title'; p 'body' } }
  H::C2 = H { footer { a 1; a 2 } }
  
  def test_that_components_can_be_composed
  
    assert_equal(
      '<div><article><h1>title</h1><p>body</p></article><footer><a>1</a><a>2</a></footer></div>',
      H { div { C1(); C2() } }.render
    )
  end

  H::C3 = ->(&inner_html) {
    H {
      header {
        h1 :foo
        e inner_html
      }
    }
  }

  def test_that_components_can_be_passed_inner_html
    assert_equal(
      '<div><header><h1>foo</h1><button>bar</button></header></div>',
      H {
        div {
          C3 {
            button :bar
          }
        }
      }.render
    )
  end

  H::C4 = ->(title, body) {
    H {h1 title; p body }
  }

  def test_that_components_can_be_passed_arbitrary_arguments
    assert_equal(
      '<div><h1>foobar</h1><p>lorem ipsum</p></div>',
      H {
        div {
          C4('foobar', 'lorem ipsum')
        }
      }.render
    )
  end
end

class ContextTest < MiniTest::Test
  def test_that_context_is_evaluated_at_render_time
    h = H {
      html {
        head {
          title context[:title]
        }
      }
    }

    assert_equal(
      '<html><head><title>foo</title></head></html>',
      h.render(title: 'foo')
    )

    assert_equal(
      '<html><head><title>bar</title></head></html>',
      h.render(title: 'bar')
    )
  end

  H::C5 = H {
    head { title context[:title] }
  }

  def test_that_context_is_accessible_to_nested_components
    assert_equal(
      '<html><head><title>foo</title></head></html>',
      H { html { C5() } }.render(title: 'foo')
    )
  end
end

class BlockTest < MiniTest::Test
  def test_that_template_block_has_access_to_local_variables
    text = 'foobar'
    assert_equal(
      '<p>foobar</p>',
      H { p text }.render
    )
  end
end

class ArgumentsTest < MiniTest::Test
  def test_that_with_passes_local_context_to_block
    comp = H { span foo }
    t = H { with(foo: 'bar') { emit comp } }

    assert_equal(
      '<span>bar</span>',
      t.render
    )
  end

  H::C6 = ->(&inner_html) {
    H {
      div {
        span foo
        emit inner_html
      }
    }
  }

  def test_that_nested_with_calls_replace_and_restore_local_context
    assert_equal(
      '<div><span>foo</span><div><span>bar</span></div></div>',
      H {
        with(foo: 'foo') {
          C6 {
            with(foo: 'bar') {
              C6()
            }
          }
        }
      }.render
    )
  end

  def ivar_h
    H(foo: @foo) { span foo }
  end

  def test_that_H_accepts_local_context
    @foo = 'bar'
    assert_equal('<span>bar</span>', ivar_h.render)
  end

  H::C7 = H { span foo }

  def test_that_rubyoshka_calls_accept_local_context
    assert_equal(
      '<span>bar</span>',
      H { C7(foo: 'bar') }.render
    )
  end
end