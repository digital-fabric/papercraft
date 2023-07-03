# frozen_string_literal: true

require 'bundler/setup'
require 'minitest/autorun'
require 'papercraft'

class ParametersTest < MiniTest::Test
  def test_ordinal_parameters
    h = Papercraft.html { |foo| h1 foo }

    assert_equal '<h1></h1>', h.render
    assert_equal '<h1>bar</h1>', h.render('bar')

    h = Papercraft.html { |foo, *rest| h2 foo; h3 rest.inspect }
    assert_equal '<h2></h2><h3>[]</h3>', h.render
    assert_equal '<h2>23</h2><h3>[]</h3>', h.render(23)
    assert_equal '<h2>42</h2><h3>[43, 44]</h3>',
      h.render(42, 43, 44)

    h = Papercraft.html { |foo = true| emit foo ? 'yes' : 'no' }
    assert_equal 'yes', h.render
    assert_equal 'no', h.render(false)
  end

  def test_named_parameters
    h = Papercraft.html { |foo:| h1 foo }
    assert_raises(Papercraft::Error) { h.render }
    assert_raises(Papercraft::Error) { h.render(bar: 1) }
    assert_equal '<h1>bar</h1>', h.render(foo: 'bar')

    h = Papercraft.html { |foo:, bar:| h2 foo; h3 bar }
    assert_raises(Papercraft::Error) { h.render }
    assert_raises(Papercraft::Error) { h.render(foo: 1) }
    assert_raises(Papercraft::Error) { h.render(bar: 2) }
    assert_equal '<h2>42</h2><h3>43</h3>',
      h.render(foo: 42, bar: 43)

    h = Papercraft.html { |foo: true| emit foo ? 'yes' : 'no' }
    assert_equal 'yes', h.render
    assert_equal 'no', h.render(foo: false)
  end

  def test_mixed_parameters
    h = Papercraft.html { |foo, bar:, baz:| h1 foo; h2 bar; h3 baz }
    assert_raises(Papercraft::Error) { h.render }
    assert_raises(Papercraft::Error) { h.render(1) }
    assert_raises(Papercraft::Error) { h.render(1, foo: 2) }
    assert_raises(Papercraft::Error) { h.render(baz: 4) }
    assert_equal '<h1>1</h1><h2>2</h2><h3>3</h3>',
      h.render(1, bar: 2, baz: 3)

    h = Papercraft.html { |foo, bar: 5, baz:| h1 foo; h2 bar; h3 baz }
    assert_raises(Papercraft::Error) { h.render }
    assert_raises(Papercraft::Error) { h.render(1) }
    assert_equal '<h1>1</h1><h2>5</h2><h3>3</h3>',
      h.render(1, baz: 3)
  end
end

class EmitComponentTest < MiniTest::Test
  def test_emit_with_proc_params
    r = Papercraft.html { |p| body { emit p } }
    assert_equal '<body><h1>hi</h1></body>', r.render(proc { h1 'hi' })
    assert_equal '<body><foo></foo></body>', r.render(proc { foo })
  end

  def test_emit_with_params
    r = Papercraft.html { |foo| body { emit foo, bar: 2 } }
    assert_raises(Papercraft::Error) { r.render(proc { |baz:| h1 baz }) }
    assert_equal '<body><h1>2</h1></body>', r.render(proc { |bar:| h1 bar })
  end

  def test_emit_with_block
    hdr = proc { |foo:|
      header { h1 foo; emit_yield }
    }
    template = Papercraft.html {
      emit(hdr, foo: 'bar') {
        button 'hi'
      }
    }
    assert_equal '<header><h1>bar</h1><button>hi</button></header>', template.render
  end
end

class EmitYieldTest < MiniTest::Test
  def test_emit_yield
    r = Papercraft.html { body { emit_yield } }
    assert_raises(Papercraft::Error) { r.render(foo: 'bar') }

    assert_equal(
      '<body><p>foo</p><hr/></body>',
      r.render { p 'foo'; hr; }
    )
  end

  def test_emit_yield_with_params
    r = Papercraft.html { |foo:| body { emit_yield(bar: foo * 10) } }
    assert_raises(Papercraft::Error) { r.render(foo: 1) }
    assert_raises(Papercraft::Error) { r.render { |bar:| p bar } }
    assert_equal(
      '<body><p>420</p></body>',
      r.render(foo: 42) { |bar:| p bar }
    )
  end
end

class ApplyTest < MiniTest::Test
  def test_apply_with_parameters
    a = Papercraft.html { |foo| body { emit foo } }
    b = a.apply(proc { p 'hi' })
    assert_kind_of Papercraft::Template, b
    assert_equal(
      '<body><p>hi</p></body>',
      b.render('hi')
    )
  end

  def test_apply_with_block
    a = Papercraft.html { |foo| body { emit_yield(foo) } }
    b = a.apply(&->(foo) { p foo })
    assert_kind_of Papercraft::Template, b
    assert_equal '<body><p>hi</p></body>', b.render('hi')
    assert_equal (a.render('foo') { |foo| p foo }), b.render('foo')
  end

  def test_apply_with_parameters_and_block
    a = Papercraft.html { |a:, b:| foo(a); body { emit_yield b } }
    b = a.apply(a: 'bar', b: 'baz') { |b| p b }

    assert_kind_of Papercraft::Template, b
    assert_equal '<foo>bar</foo><body><p>baz</p></body>', b.render
  end

  def test_apply_with_partial_parameters
    a = Papercraft.html { |foo:, bar:| p foo; p bar }
    b = a.apply(foo: 'aaa')

    assert_raises { b.render }

    assert_equal '<p>aaa</p><p>bbb</p>', b.render(bar: 'bbb')
  end

  def test_apply_with_block_with_emit_yield
    a = Papercraft.html { body { emit_yield } }
    b = a.apply { article { emit_yield } }

    c = b.render { h1 'foo' }
    assert_equal '<body><article><h1>foo</h1></article></body>', c
  end
end

class MimetypeTest < MiniTest::Test
  def test_html_mime_type
    t = Papercraft.html { foo 'bar' }
    assert_equal 'text/html', t.mime_type
  end

  def test_xml_mime_type
    t = Papercraft.xml { foo 'bar' }
    assert_equal 'application/xml', t.mime_type
  end

  def test_json_mime_type
    t = Papercraft.json { foo 'bar' }
    assert_equal 'application/json', t.mime_type
  end

  def test_custom_mime_type
    t = Papercraft.xml(mime_type: 'foo/bar') { foo 'bar' }
    assert_equal 'foo/bar', t.mime_type
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

class ConstComponentTest < MiniTest::Test
  def test_nested_composition
    page = Papercraft.html { |title, items|
      html5 {
        head { Title(title) }
        body { ItemList(items) }
      }
    }

    html = page.render('Hello from composed templates', [
      { id: 1, text: 'foo', checked: false },
      { id: 2, text: 'bar', checked: true }
    ])

    assert_equal(
      '<!DOCTYPE html><html><head><h1>Hello from composed templates</h1></head><body><ul><li><input name="1" type="checkbox"/><label for="1">foo</label></li><li><input name="2" type="checkbox" checked/><label for="2">bar</label></li></ul></body></html>',
      html
    )
  end
end

class EnumeratorTest < MiniTest::Test
  def test_enumerator_tag
    data = %w{foo bar baz}

    t = Papercraft.html {
      tr(_for: data) { |d| span d }
    }

    assert_equal(
      '<tr><span>foo</span></tr><tr><span>bar</span></tr><tr><span>baz</span></tr>',
      t.render
    )

    t = Papercraft.html {
      tr(_for: data.each_with_index) { |d, i| span i; span d }
    }

    assert_equal(
      '<tr><span>0</span><span>foo</span></tr><tr><span>1</span><span>bar</span></tr><tr><span>2</span><span>baz</span></tr>',
      t.render
    )
  end

  def test_nested_enumerator_tags
    data = [
      { name: 'foo', age: 16 },
      { name: 'bar', age: 32 },
      { name: 'baz', age: 64 },
    ]

    fields = [:name, :age]

    t = Papercraft.html {
      tbody {
        tr(_for: data) { |row|
          td(_for: fields.each_with_index) { |field, idx|
            div_class = idx == 0 ? 'text-bold' : 'text-center p-4'
            div row[field], class: div_class
          }
        }
      }
    }

    assert_equal(
      '<tbody><tr><td><div class="text-bold">foo</div></td><td><div class="text-center p-4">16</div></td></tr><tr><td><div class="text-bold">bar</div></td><td><div class="text-center p-4">32</div></td></tr><tr><td><div class="text-bold">baz</div></td><td><div class="text-center p-4">64</div></td></tr></tbody>',
      t.render
    )
  end
end
