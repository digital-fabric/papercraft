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
    Papercraft.html { o = fancy }.render

    assert_kind_of Papercraft::ExtensionProxy, o
    assert o.respond_to?(:test)
    assert_equal :foo, o.test
  end

  def test_component_method_namespacing
    h = Papercraft.html {
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

    h = Papercraft.html {
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
    h = Papercraft.html {
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

    h = Papercraft.html {
      same_name.button('bar')
    }

    assert_equal "<button>foo:bar</button>", h.render
  end

  module BootstrapComponents
    def card(**props, &block)
      div(class: 'card', **props) {
        div(class: 'card-body', &block)
      }
    end
  
    def card_title(title)
      h4(title, class: 'card-title')
    end

    def card_subtitle(subtitle)
      h5(subtitle, class: 'card-subtitle')
    end

    def card_text(text)
      p(text, class: 'card-text')
    end

    def card_link(text, **opts)
      a(text, class: 'card-link', **opts)
    end
  end

  def test_bootstrap_extension_issue_10
    Papercraft.extension(bootstrap: BootstrapComponents)

    page = Papercraft.html {
      bootstrap.card(style: 'width: 18rem') {
        bootstrap.card_title 'Card title'
        bootstrap.card_subtitle 'Card subtitle'
        bootstrap.card_text 'Some quick example text to build on the card title and make up the bulk of the card''s content.'
        bootstrap.card_link 'Card link', href: '#foo'
        bootstrap.card_link 'Another link', href: '#bar'
      }
    }

    assert_equal(
      '<div class="card" style="width: 18rem"><div class="card-body"><h4 class="card-title">Card title</h4><h5 class="card-subtitle">Card subtitle</h5><p class="card-text">Some quick example text to build on the card title and make up the bulk of the cards content.</p><a class="card-link" href="%23foo">Card link</a><a class="card-link" href="%23bar">Another link</a></div></div>',
      page.render
    )
  end
end

class InlineExtensionsTest < MiniTest::Test
  def test_inline_def
    t = Papercraft.html {
      def part(text)
        span text, class: 'part'
      end

      part 'foo'
      part 'bar'
    }

    assert_equal '<span class="part">foo</span><span class="part">bar</span>', t.render
  end

  def test_def_tag
    t = Papercraft.html {
      def_tag(:part) { |t, **a, &b| div(class: 'part', **a) { h1 t; emit b } }

      part('foo', id: 'bar') {
        p 'hello'
      }
    }

    assert_equal '<div class="part" id="bar"><h1>foo</h1><p>hello</p></div>', t.render
  end
end
