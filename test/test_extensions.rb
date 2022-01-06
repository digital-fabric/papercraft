# frozen_string_literal: true

require 'bundler/setup'
require 'minitest/autorun'
require 'papercraft'

class ExtensionsTest < MiniTest::Test
  module FancySchmancy
    def test
      :foo
    end

    def carousel(**args, &block)
      div(class: 'carousel', **args) { emit block }
    end

    def carousel_item(**args, &block)
      div(class: 'carousel-item', **args) { emit block }
    end
  end

  def test_component_library_installation
    Papercraft.extension(fancy: FancySchmancy)
    o = nil
    H { o = fancy }.render

    assert_kind_of Papercraft::ExtensionProxy, o
    assert o.respond_to?(:test)
    assert_equal :foo, o.test
  end

  def test_component_method_namespacing
    h = H {
      carousel(id: 'foo') {
        carousel_item(id: 'bar') {
          h1 'hi'
        }
      }
    }

    assert_equal '<carousel id="foo"><carousel-item id="bar"><h1>hi</h1></carousel-item></carousel>', h.render
  end

  def test_component_rendering
    Papercraft.extension(fancy: FancySchmancy)

    h = H {
      fancy.carousel(id: 'foo') {
        fancy.carousel_item(id: 'bar') {
          h1 'hi'
        }
      }
    }

    assert_equal '<div class="carousel" id="foo"><div class="carousel-item" id="bar"><h1>hi</h1></div></div>', h.render
  end

  module DirectExtensions
    def fancy_div(*args, &block)
      div(*args) { emit block }
    end
  end

  def test_module_include
    Papercraft::HTMLRenderer.include DirectExtensions
    h = H {
      fancy_div(id: 'd1')
      fancy_div(id: 'd2') { text 'foo' }
    }
    assert_equal '<div id="d1"></div><div id="d2">foo</div>', h.render
  end

  module SameNameExtensions
    def button(text)
      tag :button, "foo:#{text}"
    end
  end

  def test_same_name_extension_method
    Papercraft.extension(same_name: SameNameExtensions)

    h = H {
      same_name.button('bar')
    }

    assert_equal "<button>foo:bar</button>", h.render
  end
end
