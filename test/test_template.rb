require 'bundler/setup'
require 'minitest/autorun'
require 'rubyoshka'

class EntryPointTest < MiniTest::Test
  def test_that_entry_point_creates_new_instance
    block = proc { }
    h = H(&block)

    assert_kind_of(H, h)
    assert_equal(block, h.template)
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

  H::BlogPost = Rubyoshka.component do |title, content|
    article(id: '42') do
      h1 title
      p content
    end
  end

  def test_rubyoshka_component_method
    assert_equal(
      '<div><article id="42"><h1>foo</h1><p>bar</p></article></div>',
      H {
        div {
          # C4('foobar', 'lorem ipsum')
          BlogPost('foo', 'bar')
        }
      }.render
    )
  end
end

class ModuleComponentTest < MiniTest::Test
  module M
    Component = H { p 'foobar' }
  end

  def test_that_module_component_can_be_emitted
    assert_equal(
      '<div><p>foobar</p></div>',
      H { div { e(M) } }.render
    )
  end

  module N
  end

  def test_that_module_without_component_raises
    assert_raises {
      H { div { e(N) } }.render
    }
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

class ScopeTest < MiniTest::Test
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

class CacheTest < MiniTest::Test
  H::C8 = H {
    cache {
      context[:meaning] = 42
      div {
        span "hello"
        span "world"
      }
    }
  }

  def test_that_cache_hits_when_rendering_again
    H.cache.clear
    global = {}
    assert_equal(
      '<div><span>hello</span><span>world</span></div>',
      H::C8.render(global)
    )
    assert_equal(42, global[:meaning])
    assert_equal(1, H.cache.size)

    global[:meaning] = nil
    assert_equal(
      '<div><span>hello</span><span>world</span></div>',
      H::C8.render(global)
    )
    assert_nil(global[:meaning])
  end

  H::C9 = H {
    cache(context[:name]) {
      context[:meaning] = 42
      div {
        span "hello, #{context[:name]}"
      }
    }
  }

  def test_that_separate_cache_entries_are_created_for_different_signatures
    H.cache.clear
    global = { name: 'world' }

    assert_equal(
      '<div><span>hello, world</span></div>',
      H::C9.render(global)
    )
    assert_equal(42, global[:meaning])
    assert_equal(1, H.cache.size)

    global[:meaning] = nil
    assert_equal(
      '<div><span>hello, world</span></div>',
      H::C9.render(global)
    )
    assert_nil(global[:meaning])

    global[:name] = 'dolly'
    assert_equal(
      '<div><span>hello, dolly</span></div>',
      H::C9.render(global)
    )
    assert_equal(42, global[:meaning])
    assert_equal(2, H.cache.size)
  end

  H::C10 = H {
    cache(name) {
      div {
        span "hello, #{name}"
      }
    }
  }

  def test_that_multiple_cache_blocks_work_correctly
    H.cache.clear

    template = H {
      C10(name: 'world')
      C10(name: 'dolly')
    }

    assert_equal(
      '<div><span>hello, world</span></div><div><span>hello, dolly</span></div>',
      template.render
    )

    assert_equal(2, H.cache.size)
  end

  def test_that_cache_adapter_can_be_changed
    ::H.class_eval {
      class << self
        def store
          @store ||= {}
        end

        alias_method :orig_cache, :cache
        def cache
          @store
        end
      end
    }

    assert_equal(0, ::H.store.size)
    assert_equal(
      '<div><span>hello, world</span></div>',
      H { C10(name: 'world') }.render
    )
    assert_equal(1, ::H.store.size)
  ensure
    ::H.class_eval {
      class << self
        alias_method :cache, :orig_cache
      end
    }
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
    xml = H.xml {
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
    xml = H.xml {
      link 'http://liftoff.msfc.nasa.gov/news/2003/news-starcity.asp'
    }

    assert_equal(
      '<link>http://liftoff.msfc.nasa.gov/news/2003/news-starcity.asp</link>',
      xml.render
    )
  end
end
