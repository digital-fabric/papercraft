# require 'bundler/setup'
# require 'minitest/autorun'
# require 'rubyoshka'

# class ParametersTest < MiniTest::Test
#   def test_ordinal_parameters
#     h = H { |foo| h1 foo }

#     assert_raises(Rubyoshka::Error) { h.render }
#     assert_equal '<h1>bar</h1', h.render('bar')

#     h = H { |foo, *rest| h2 foo; h3 rest.inspect }
#     assert_raises(Rubyoshka::Error) { h.render }
#     assert_raises(Rubyoshka::Error) { h.render('bar', 2, 3) }
#     assert_equal '<h2>42</h2><h3>[43, 44]</h3>',
#       h.render(42, 43, 44)
    
#     h = H { |foo = true| emit foo ? 'yes' : 'no' }
#     assert_equal 'yes', h.render
#     assert_equal 'no', h.render(false)
#   end

#   def test_named_parameters
#     h = H { |foo:| h1 foo }
#     assert_raises(Rubyoshka::Error) { h.render }
#     assert_raises(Rubyoshka::Error) { h.render(bar: 1) }
#     assert_equal '<h1>bar</h1>', h.render(foo: 'bar')

#     h = H { |foo:, **rest| h2 foo; h3 rest[:bar] }
#     assert_raises(Rubyoshka::Error) { h.render }
#     assert_raises(Rubyoshka::Error) { h.render(foo: 1) }
#     assert_raises(Rubyoshka::Error) { h.render(bar: 2) }
#     assert_equal '<h2>42</h2><h3>43</h3>',
#       h.render(foo: 42, bar: 43)
    
#     h = H { |foo: true| emit foo ? 'yes' : 'no' }
#     assert_equal 'yes', h.render
#     assert_equal 'no', h.render(foo: false)
#   end

#   def test_mixed_parameters
#     h = H { |foo, bar:, baz:| h1 foo; h2 bar; h3 baz }
#     assert_raises(Rubyoshka::Error) { h.render }
#     assert_raises(Rubyoshka::Error) { h.render(1) }
#     assert_raises(Rubyoshka::Error) { h.render(1, foo: 2) }
#     assert_raises(Rubyoshka::Error) { h.render(1, bar: 3, baz: 4) }
#     assert_equal '<h1>1</h1><h2>2</h2><h3>3</h3>',
#       h.render(1, bar: 2, baz: 3)
    
#     h = H { |foo, bar: 5, baz:| h1 foo; h2 bar; h3 baz }
#     assert_raises(Rubyoshka::Error) { h.render }
#     assert_raises(Rubyoshka::Error) { h.render(1) }
#     assert_equal '<h1>1</h1><h2>5</h2><h3>3</h3>',
#       h.render(1, baz: 3)
#   end
# end

# class EmitYieldTest < MiniTest::Test
#   def test_emit_yield
#     r = H { body { emit_yield } }
#     assert_raises(Rubyoshka::Error) { r.render(foo: 'bar') }

#     assert_equal(
#       '<body><p>foo</p><hr/></body>',
#       r.render { p 'foo'; hr; }
#     )
#   end

#   def test_emit_yield_with_params
#     r = H { |foo| body { emit_yield(bar: foo * 10) } }
#     assert_raises(Rubyoshka::Error) { r.render(1) }
#     assert_raises(Rubyoshka::Error) { r.render { |foo| p foo } }
#     assert_equal(
#       '<body><p>420</p></body>',
#       r.render(42) { |bar:| p bar }
#     )
#   end
# end

# class ApplyTest < MiniTest::Test
#   def test_apply_with_parameters
#     a = H { |foo| body { emit foo } }
#     b = a.apply(-> { p 'hi' })
#     assert_kind_of Rubyoshka, b
#     assert_equal(
#       '<body><p>hi</p></body>',
#       b.render
#     )
#   end

#   def test_apply_with_block
#     a = H { |foo| body { emit_yield(foo) } }
#     b = a.apply(->(foo) { p foo })
#     assert_kind_of Rubyoshka, b
#     assert_equal '<body><p>hi</p></body>', b.render('hi')
#     assert_equal (a.render('foo') { |foo| p foo }), b.render('foo')
#   end
# end
