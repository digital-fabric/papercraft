# frozen_string_literal: true

require_relative './helper'

class ParametersTest < Minitest::Test
  def test_empty_template
    t = -> { }
    assert_equal '', Papercraft.html(t)

    t = ->(foo) { }
    assert_raises(ArgumentError) { Papercraft.html(t) }
    assert_equal '', Papercraft.html(t, 1)
  end

  def test_simple_template
    h = ->(foo) { h1 foo }

    assert_raises(ArgumentError) { Papercraft.html(h) }
    assert_equal '<h1>bar</h1>', Papercraft.html(h, 'bar')
  end

  def test_ordinal_parameters
    h = proc { |foo = 'baz'| h1 foo }

    assert_equal '<h1>baz</h1>', Papercraft.html(h)
    assert_equal '<h1>bar</h1>', Papercraft.html(h, 'bar')

    h = proc { |foo = 'default', *rest| h2 foo; h3 rest.inspect }
    assert_equal '<h2>default</h2><h3>[]</h3>', Papercraft.html(h)     
    assert_equal '<h2>23</h2><h3>[]</h3>', Papercraft.html(h, 23)
    assert_equal '<h2>42</h2><h3>[43, 44]</h3>', Papercraft.html(h, 42, 43, 44)

    h = ->(foo = true) { raw(foo ? 'yes' : 'no') }
    assert_equal 'yes', Papercraft.html(h)
    assert_equal 'no', Papercraft.html(h, false)
  end

  def test_named_parameters
    h = proc { |foo:| h1 foo }
    assert_raises(ArgumentError) { Papercraft.html(h) }
    assert_raises(ArgumentError) { Papercraft.html(h, bar: 1) }
    assert_equal '<h1>bar</h1>', Papercraft.html(h, foo: 'bar')

    h = proc { |foo:, bar:| h2 foo; h3 bar }
    assert_raises(ArgumentError) { Papercraft.html(h) }
    assert_raises(ArgumentError) { Papercraft.html(h, foo: 1) }
    assert_raises(ArgumentError) { Papercraft.html(h, bar: 2) }
    assert_equal '<h2>42</h2><h3>43</h3>', Papercraft.html(h, foo: 42, bar: 43)

    h = proc { |foo: true| raw foo ? 'yes' : 'no' }
    assert_equal 'yes', Papercraft.html(h)
    assert_equal 'no', Papercraft.html(h, foo: false)
  end

  def test_mixed_parameters
    h = proc { |foo, bar:, baz:| h1 foo; h2 bar; h3 baz }
    assert_raises(ArgumentError) { Papercraft.html(h) }
    assert_raises(ArgumentError) { Papercraft.html(h, 1) }
    assert_raises(ArgumentError) { Papercraft.html(h, 1, foo: 2) }
    assert_raises(ArgumentError) { Papercraft.html(h, baz: 4) }
    assert_equal '<h1>1</h1><h2>2</h2><h3>3</h3>', Papercraft.html(
      h, 1, bar: 2, baz: 3
    )

    h = proc { |foo, bar: 5, baz:| h1 foo; h2 bar; h3 baz }
    assert_raises(ArgumentError) { Papercraft.html(h) }
    assert_raises(ArgumentError) { Papercraft.html(h, 1) }
    assert_equal '<h1>1</h1><h2>5</h2><h3>3</h3>', Papercraft.html(
      h, 1, baz: 3
    )
  end
end

class RenderComponentTest < Minitest::Test
  def test_render_with_proc_params
    r = proc { |p| body { render p } }
    assert_equal '<body><h1>hi</h1></body>', Papercraft.html(
      r, proc { h1 'hi' }
    )
    assert_equal '<body><foo></foo></body>', Papercraft.html(
      r, proc { foo }
    )
  end

  def test_render_with_params
    r = proc { |foo|
      body {
        render foo, bar: 2
      }
    }
    assert_raises(ArgumentError) {
      Papercraft.html(
        r, proc { |baz:|
          h1 baz
        }
      )
    }
    assert_equal '<body><h1>2</h1></body>', Papercraft.html(
      r, proc { |bar:|
        h1 bar
      }
    )
  end

  def test_render_with_block
    hdr = proc { |foo:|
      header { h1 foo; render_yield }
    }
    template = proc {
      render(hdr, foo: 'bar') {
        button 'hi'
      }
    }
    assert_equal '<header><h1>bar</h1><button>hi</button></header>', 
      Papercraft.html(template)
  end

  Foo = ->(name) { h1 "Hello, #{name}!" }

  def test_render_constant_component
    template = -> {
      div { render Foo, 'foo' }
    }
    assert_equal "<div><h1>Hello, foo!</h1></div>", Papercraft.html(template)

    template = -> {
      div { Foo('bar') }
    }
    assert_equal "<div><h1>Hello, bar!</h1></div>", Papercraft.html(template)
  end

  module Blah
    Foo = ->(name) { h2 "Hello, #{name}!" }
  end

  def test_render_namespaced_constant_component
    template = -> {
      div { render Blah::Foo, 'foo' }
    }
    assert_equal "<div><h2>Hello, foo!</h2></div>", Papercraft.html(template)

    template = -> {
      div { Blah::Foo('bar') }
    }
    assert_equal "<div><h2>Hello, bar!</h2></div>", Papercraft.html(template)
  end

  module A
    module B
      Foo = ->(name) { h3 "Hello, #{name}!" }
    end
  end

  def test_render_deeply_namespaced_constant_component
    template = -> {
      div { render A::B::Foo, 'foo' }
    }
    assert_equal "<div><h3>Hello, foo!</h3></div>", Papercraft.html(template)

    template = -> {
      div { A::B::Foo('bar') }
    }
    assert_equal "<div><h3>Hello, bar!</h3></div>", Papercraft.html(template)
  end

  def test_render_invalid_constant_component
    template = -> {
      div { Bar('foo') }
    }
    assert_raises(NameError) { Papercraft.html(template) }

    template = -> {
      div { Blah::Bar('foo') }
    }
    assert_raises(NameError) { Papercraft.html(template) }

    template = -> {
      div { A::B::Bar('foo') }
    }
    assert_raises(NameError) { Papercraft.html(template) }
  end

  module ::C
    Foo = ->(name) { h4 "Hello, #{name}!" }
  end

  def test_render_global_namespaced_constant_component
    template = -> {
      div { render ::C::Foo, 'foo' }
    }
    assert_equal "<div><h4>Hello, foo!</h4></div>", Papercraft.html(template)

    template = -> {
      div { ::C::Foo('bar') }
    }
    assert_equal "<div><h4>Hello, bar!</h4></div>", Papercraft.html(template)
  end


end

class RenderYieldTest < Minitest::Test
  def test_render_yield
    r = proc { body { render_yield } }
    assert_raises(ArgumentError) { Papercraft.html(r, foo: 'bar') }

    assert_equal(
      '<body><p>foo</p><hr></body>',
      Papercraft.html(r) { p 'foo'; hr; }
    )
  end

  def test_render_yield_with_params
    r = proc { |foo:| body { render_yield(bar: foo * 10) } }
    assert_raises(LocalJumpError) { Papercraft.html(r, foo: 1) }
    assert_raises(ArgumentError) { Papercraft.html(r) { |bar:| p bar } }
    assert_equal(
      '<body><p>420</p></body>',
      Papercraft.html(r, foo: 42) { |bar:| p bar }
    )
  end
end

class RenderChildrenTest < Minitest::Test
  def test_render_children
    r = proc { body { render_children } }

    assert_raises(ArgumentError) { Papercraft.html(r, foo: 'bar') }
    assert_equal '<body></body>', Papercraft.html(r)
    assert_equal '<body><p>foo</p><hr></body>', Papercraft.html(r) { p 'foo'; hr; }
  end

  def test_render_children_with_params
    r = proc { |foo:| body { render_children(bar: foo * 10) } }

    assert_equal '<body></body>', Papercraft.html(r, foo: 1)
    assert_raises(ArgumentError) { Papercraft.html(r) { |bar:| p bar } }
    assert_equal(
      '<body><p>420</p></body>',
      Papercraft.html(r, foo: 42) { |bar:| p bar }
    )
  end
end

class BlockCallTest < Minitest::Test
  def test_block_call
    a = ->(&foo) {
      div {
        foo.()
      }
    }
    html = Papercraft.html(a) { h1 'hi' }
    assert_equal '<div><h1>hi</h1></div>', html

    b = Papercraft.apply(a) { p 'ho' }
    assert_equal '<div><p>ho</p></div>', Papercraft.html(b)

    assert_raises(NoMethodError) { Papercraft.html(a) }
  end

  def test_block_call_with_block
    a = ->(&foo) {
      div {
        foo.() {
          bar 'baz'
        }
      }
    }
    assert_raises(Papercraft::Error) {
      Papercraft.apply(a) { |&c|
        span(&c)
      }
    }
  end

  def test_block_passing
    a = ->(&foo) {
      div(&foo)
    }
    html = Papercraft.html(a) { h1 'hi' }
    assert_equal '<div><h1>hi</h1></div>', html
  end
end

class ApplyTest < Minitest::Test
  def test_apply_with_parameters
    a = proc { |foo| body { render foo } }
    b = Papercraft.apply(a, proc { p 'hi' })

    assert_kind_of Proc, b
    assert b.__papercraft_compiled?
    assert_equal(
      '<body><p>hi</p></body>',
      Papercraft.html(b)
    )
  end

  def test_apply_with_block
    a = proc { |foo| body { render_yield(foo) } }
    b = Papercraft.apply(a, &->(foo) { p foo })
    assert_equal '<body><p>hi</p></body>', Papercraft.html(b, 'hi')
    assert_equal (Papercraft.html(a, 'foo') { |foo| p foo }), Papercraft.html(b, 'foo')
  end

  def test_apply_with_parameters_and_block
    a = proc { |a:, b:|
      foo(a);
      body {
        render_yield b
      }
    }
    b = Papercraft.apply(a, a: 'bar', b: 'baz') { |x, **| p x }

    assert_kind_of Proc, b
    assert_equal '<foo>bar</foo><body><p>baz</p></body>', Papercraft.html(b)
  end

  def test_apply_with_partial_parameters
    a = proc { |foo:, bar:| p foo; p bar }
    b = Papercraft.apply(a, foo: 'aaa')

    assert_raises { Papercraft.html(b) }

    assert_equal '<p>aaa</p><p>bbb</p>', Papercraft.html(b, bar: 'bbb')
  end

  def test_apply_with_block_with_yield
    a = proc { body { render_yield } }
    b = Papercraft.apply(a) { article { render_yield } }

    c = Papercraft.html(b) { h1 'foo' }
    assert_equal '<body><article><h1>foo</h1></article></body>', c
  end

  def test_apply_with_block_with_yield_with_args
    a = proc { |*a, **b| body { render_yield(*a, **b) } }
    b = Papercraft.apply(a, :foo, :bar, p: 42, q: 43) { |*c, **d|
      article { render_yield(*c, **d) }
    }

    buf = []
    c = Papercraft.html(b, :baz, :but, x: 1, y: 2) { |*a, **b|
      buf << a << b
      h1 "foo"
    }
    assert_equal '<body><article><h1>foo</h1></article></body>', c
    assert_equal [
      [:foo, :bar, :baz, :but],
      {
        p: 42,
        q: 43,
        x: 1,
        y: 2
      }
    ], buf
  end

  def test_apply_with_block_render_with_block
    a = proc { |*a, **b| body { render_yield(*a, **b) } }
    b = Papercraft.apply(a, :foo, :bar, p: 42, q: 43) { |*c, **d|
      article { render_yield(*c, **d) }
    }

    buf = []
    c = Papercraft.html(b, :baz, :but, x: 1, y: 2) { |*a, **b|
      buf << a << b
      h1 "foo"
    }
    
  end
end

Title = ->(title) { h1 title }

Item = ->(id:, text:, checked:) {
  li {
    input name: id, type: 'checkbox', checked: checked
    label text, for: id
  }
}

ItemList = ->(items) {
  ul {
    items.each { |i|
      Item(**i)
    }
  }
}

class ConstComponentTest < Minitest::Test
  def test_nested_composition
    page = proc { |title, items|
      html5 {
        head { Title(title) }
        body { ItemList(items) }
      }
    }

    html = Papercraft.html(page, 'Hello from composed templates', [
      { id: 1, text: 'foo', checked: false },
      { id: 2, text: 'bar', checked: true }
    ])

    assert_equal(
      '<!DOCTYPE html><html><head><h1>Hello from composed templates</h1></head><body><ul><li><input name="1" type="checkbox"><label for="1">foo</label></li><li><input name="2" type="checkbox" checked><label for="2">bar</label></li></ul></body></html>',
      html
    )
  end
end

class TagsTest < Minitest::Test
  def test_tag
    t = -> {
      h1 'foo'
      tag :h2, 'bar'
    }
    html = Papercraft.html(t)
    assert_equal('<h1>foo</h1><h2>bar</h2>', html)
  end

  def test_tag_with_attrs_and_block
    t = -> {
      h1 'foo', id: '42'
      tag(:h2, id: '43') {
        span 'bar'
      }
    }
    html = Papercraft.html(t)
    assert_equal('<h1 id="42">foo</h1><h2 id="43"><span>bar</span></h2>', html)

    t = -> {
      h1 'foo', 'id_foo': '43'
      tag(:h2, 'x-y' => '44') {
        span 'bar'
      }
    }
    html = Papercraft.html(t)
    assert_equal('<h1 id-foo="43">foo</h1><h2 x-y="44"><span>bar</span></h2>', html)
  end

  def test_dynamic_tag
    t = ->(t) {
      tag t, 'foo'
    }
    html = Papercraft.html(t, :em)
    assert_equal('<em>foo</em>', html)
  end

  def test_markdown
    t = -> {
      div {
        markdown "# Foo\n\nLorem ipsum"
      }
    }
    html = Papercraft.html(t)
    assert_equal("<div><h1 id=\"foo\">Foo</h1>\n\n<p>Lorem ipsum</p>\n</div>", html)
  end

  def test_markdown
    t = -> {
      div {
        markdown "# Foo\n\nLorem ipsum"
      }
    }
    html = Papercraft.html(t)
    assert_equal("<div><h1 id=\"foo\">Foo</h1>\n\n<p>Lorem ipsum</p>\n</div>", html)
  end
end

class ExceptionBacktraceTest < Minitest::Test
  def capture_exception
    yield
    nil
  rescue Exception => e
    e
  end

  def test_exception_backtrace
    t_line = __LINE__
    t = ->(x) {
      h1 'foo'
      raise if x
      h2 'bar'
    }

    html = Papercraft.html(t, false)
    assert_equal '<h1>foo</h1><h2>bar</h2>', html

    e = capture_exception { Papercraft.html(t, true) }
    assert_kind_of RuntimeError, e
    bt = e.backtrace
    assert_equal "#{__FILE__}:#{t_line + 3}", bt[0].match(/^(.+\:\d+)/)[1]
  end

  def test_exception_backtrace_raise_on_last_line
    t_line = __LINE__
    t = ->(x) {
      h1 'foo'
      raise if x
    }

    html = Papercraft.html(t, false)
    assert_equal '<h1>foo</h1>', html

    e = capture_exception { Papercraft.html(t, true) }
    assert_kind_of RuntimeError, e
    bt = e.backtrace
    assert_equal "#{__FILE__}:#{t_line + 3}", bt[0].match(/^(.+\:\d+)/)[1]
  end

  def test_exception_backtrace_nested
    t1_line = __LINE__
    t1 = -> {
      p 'foo'
      raise
    }
    t2 = -> {
      p 'bar'
      render t1
    }

    e = capture_exception { Papercraft.html(t2) }
    assert_kind_of RuntimeError, e
    bt = e.backtrace
    assert_equal "#{__FILE__}:#{t1_line + 3}", bt[0].match(/^(.+\:\d+)/)[1]
  end

  def test_exception_backtrace_missing_block
    t1_line = __LINE__
    t1 = -> {
      p 'foo'
      render_yield
    }
    t2 = -> {
      p 'bar'
      render t1
    }

    e = capture_exception { Papercraft.html(t2) }
    assert_kind_of LocalJumpError, e
    f = e.backtrace[0]
    assert_equal "#{__FILE__}:#{t1_line + 3}", f.match(/^(.+\:\d+)/)[1]
  end

  def test_exception_argument_error
    t_line = __LINE__
    t = ->(foo) {
      p 'foo'
    }

    e = capture_exception { Papercraft.html(t) }
    assert_kind_of ArgumentError, e
    f = e.backtrace[0]
    assert_equal "#{__FILE__}:#{t_line + 1}", f.match(/^(.+\:\d+)/)[1]

    m = e.message.match(/given (\d+), expected (\d+)/)
    assert_equal 0, m[1].to_i
    assert_equal 1, m[2].to_i
  end
end

class TemplateWrapperTest < Minitest::Test
  def test_wrapper_exception_backtrace
    t = Papercraft::Template.new(->(x) {
      p x.to_s(16)
    })

    assert_equal "<p>2a</p>", t.render(42)
    assert_equal "<p>2a</p>", t.call(42)
    assert_equal "<p>2a</p>", Papercraft.html(t, 42)
    assert_equal "<p>2a</p>", Papercraft.html(t.proc, 42)

    t2 = t.apply(43)

    assert_kind_of Papercraft::Template, t2
    assert_equal "<p>2b</p>", Papercraft.html(t2)
    assert_equal "<p>2b</p>", Papercraft.html(t2.proc)
  end

  def test_wrapper_xml
    t = Papercraft::Template.new(-> { link 'foo' }, mode: :xml)
    assert_equal "<link>foo</link>", t.render
    assert_equal :xml, t.mode
  end

  def test_wrapper_with_block
    t = Papercraft::Template.new { |x|
      p x.to_s(16)
    }
    assert_equal "<p>2a</p>", t.render(42)
    assert_equal "<p>2a</p>", t.call(42)
  end
end

class ExtensionTest < Minitest::Test
  EXT = {
    youtube_player: ->(ref) {
      iframe(
        width: 560,
        height: 315,
        src: "https://www.youtube-nocookie.com/embed/#{ref}"
      )
    },
    ulist: ->(list) {
      ul {
        list.each { li { render_yield it } }
      }
    }
  }

  def test_extension
    Papercraft.extension(EXT)

    t = -> {
      youtube_player('foo')
    }
    assert_equal '<iframe width="560" height="315" src="https://www.youtube-nocookie.com/embed/foo"></iframe>', Papercraft.html(t)
  end

  def test_extension_with_block
    Papercraft.extension(EXT)

    t = -> {
      ulist([1, 2, 3]) { |item|
        p (item * 10)
      }
    }
    assert_equal '<ul><li><p>10</p></li><li><p>20</p></li><li><p>30</p></li></ul>', Papercraft.html(t)

    t = -> {
      ulist([1, 2, 3]) {
        p (it * 10)
      }
    }
    assert_raises(Papercraft::Error) { Papercraft.html(t) }
  end
end

class RenderCacheTest < Minitest::Test
  def test_render_cache
    counter = 0
    t = ->(*args) {
      counter += 1
      p args.join
    }

    assert_equal '<p>foo</p>', Papercraft.cache_html(t, :foo, :foo)
    assert_equal 1, counter
    assert_equal '<p>foo</p>', Papercraft.cache_html(t, :foo, :foo)
    assert_equal 1, counter
    assert_equal '<p>foo</p>', Papercraft.cache_html(t, :foo, :bar)
    assert_equal 1, counter

    assert_equal '<p>bar</p>', Papercraft.cache_html(t, :bar, :bar)
    assert_equal 2, counter
    assert_equal '<p>bar</p>', Papercraft.cache_html(t, :bar, :bar)
    assert_equal 2, counter

    assert_equal '<p>foobar</p>', Papercraft.cache_html(t, :baz, :foo, :bar)
    assert_equal 3, counter
    assert_equal '<p>foobar</p>', Papercraft.cache_html(t, :baz, :foo, :bar)
    assert_equal 3, counter
  end
end

class EvaldProcTest < Minitest::Test
  def test_eval_proc_error
    t = eval('-> { hr }')
    assert_raises(Papercraft::Error) { Papercraft.html(t) }
  end
end

class StringEscapingTest < Minitest::Test
  def test_string_escaping_raw
    s = 'abc "def" ghi'
    t = -> {
      raw 'abc "def" ghi'
    }
    assert_equal 'abc "def" ghi', Papercraft.html(t)

    t = -> {
      raw s
    }
    assert_equal 'abc "def" ghi', Papercraft.html(t)

    t = -> {
      text 'abc "def" ghi'
    }
    assert_equal 'abc &quot;def&quot; ghi', Papercraft.html(t)

    t = -> {
      p 'abc "def" ghi'
    }
    assert_equal '<p>abc &quot;def&quot; ghi</p>', Papercraft.html(t)

    t = -> {
      p s
    }
    assert_equal '<p>abc &quot;def&quot; ghi</p>', Papercraft.html(t)
  end
end

class AttributeInjectionTest < Minitest::Test
  def test_attribute_injection_no_atts
    line = __LINE__
    t = -> {
      p 'foo'
    }

    Papercraft::Compiler.html_debug_attribute_injector = ->(level, fn, line, col) {
      { 'data-papercraft-fn' => fn, 'data-papercraft-loc' => "foo://#{fn}:#{line}:#{col}" }
    }

    html = Papercraft.html(t)

    assert_equal "<p data-papercraft-fn=\"#{__FILE__}\" data-papercraft-loc=\"foo://#{__FILE__}:#{line + 2}:7\">foo</p>", html
  ensure
    Papercraft::Compiler.html_debug_attribute_injector = nil
  end

  def test_attribute_injection_static_atts
    line = __LINE__
    t = -> {
      p 'foo', class: 'bar', baz: true, ynot: nil
    }

    Papercraft::Compiler.html_debug_attribute_injector = ->(level, fn, line, col) {
      { 'data-papercraft-fn' => fn, 'data-papercraft-loc' => "foo://#{fn}:#{line}:#{col}" }
    }

    html = Papercraft.html(t)

    assert_equal "<p data-papercraft-fn=\"#{__FILE__}\" data-papercraft-loc=\"foo://#{__FILE__}:#{line + 2}:7\" class=\"bar\" baz>foo</p>", html
  ensure
    Papercraft::Compiler.html_debug_attribute_injector = nil
  end

  def test_attribute_injection_dynamic_atts
    line = __LINE__
    atts = { baz: true, ynot: nil }
    t = -> {
      p 'foo', class: 'bar', **atts
    }

    Papercraft::Compiler.html_debug_attribute_injector = ->(level, fn, line, col) {
      { 'data-papercraft-fn' => fn, 'data-papercraft-loc' => "foo://#{fn}:#{line}:#{col}" }
    }

    html = Papercraft.html(t)
    assert_equal "<p data-papercraft-fn=\"#{__FILE__}\" data-papercraft-loc=\"foo://#{__FILE__}:#{line + 3}:7\" class=\"bar\" baz>foo</p>", html
  ensure
    Papercraft::Compiler.html_debug_attribute_injector = nil
  end

  def test_attribute_injection_nested
    line = __LINE__
    t = -> {
      div {
        h1 {
          span 'foo'
        }
      }
    }

    Papercraft::Compiler.html_debug_attribute_injector = ->(level, fn, line, col) {
      { 'data-papercraft-level' => level, 'data-papercraft-fn' => fn, 'data-papercraft-loc' => "foo://#{fn}:#{line}:#{col}" }
    }

    html = Papercraft.html(t)

    expected = "<div data-papercraft-level=\"1\" data-papercraft-fn=\"#{__FILE__}\" data-papercraft-loc=\"foo://#{__FILE__}:#{line + 2}:7\">" +
               "<h1 data-papercraft-level=\"2\" data-papercraft-fn=\"#{__FILE__}\" data-papercraft-loc=\"foo://#{__FILE__}:#{line + 3}:9\">" +
               "<span data-papercraft-level=\"3\" data-papercraft-fn=\"#{__FILE__}\" data-papercraft-loc=\"foo://#{__FILE__}:#{line + 4}:11\">foo</span></h1></div>"
    assert_equal expected, html
  ensure
    Papercraft::Compiler.html_debug_attribute_injector = nil
  end
end

class RawIOnnerTextTest < Minitest::Test
  def test_script_tag_with_content
    t = -> {
      script 'let a = 1 & 2; let b = "abc";'
    }

    assert_equal '<script>let a = 1 & 2; let b = "abc";</script>', Papercraft.html(t)
  end

  def test_script_tag_module_with_content
    t = -> {
      script 'let a = 1 & 2; let b = "abc";', type: 'module'
    }

    assert_equal '<script type="module">let a = 1 & 2; let b = "abc";</script>', Papercraft.html(t)
  end

  def test_style_tag_with_content
    t = -> {
      style 'a&b { color: black }'
    }

    assert_equal '<style>a&b { color: black }</style>', Papercraft.html(t)
  end

  def test_script_tag_module_with_content
    t = -> {
      style 'a&b { color: black }', media: '(width < 500px)'
    }

    assert_equal '<style media="(width < 500px)">a&b { color: black }</style>', Papercraft.html(t)
  end
end

class MethodChainingTest < Minitest::Test
  def foo
    [:foo, :bar]
  end

  def test_receiverless_method_chaining
    t = -> {
      foo
    }
    assert_equal '<foo></foo>', Papercraft.html(t)

    t = -> {
      foo[0]
    }
    assert_equal '<foo></foo>', Papercraft.html(t)

    buf = []
    t = -> {
      buf.size
    }
    assert_equal '', Papercraft.html(t)
  end
end
