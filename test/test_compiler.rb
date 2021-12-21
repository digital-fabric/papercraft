# require 'bundler/setup'
# require 'minitest/autorun'
# require 'papercraft'

# class CompilerTest < MiniTest::Test
#   class Papercraft::Compiler
#     attr_accessor :level
#   end

#   def compiled_template(tmpl, level = 1)
#     c = Papercraft::Compiler.new
#     c.level = level
#     c.compile(tmpl)
#   end

#   def compiled_template_body(tmpl)
#     compiled_template(tmpl, 0).code_buffer
#   end

#   def compiled_template_code(tmpl)
#     compiled_template(tmpl).to_code
#   end

#   def compiled_template_proc(tmpl)
#     compiled_template(tmpl).to_proc
#   end

#   def test_compiler_simple
#     templ = H {
#       h1 'foo'
#       h2 'bar'
#     }

#     code = compiled_template_code(templ)
#     expected = <<~RUBY.chomp
#       ->(__buffer__, __context__) do
#         __buffer__ << "<h1>foo</h1><h2>bar</h2>"
#       end
#     RUBY
#     assert_equal expected, code
#   end

#   def test_compiler_simple_with_attributes
#     templ = H {
#       h1 'foo', class: 'foot'
#       h2 'bar', id: 'bar', onclick: "f(\"abc\", \"def\")"
#     }

#     code = compiled_template_code(templ)
#     expected = <<~RUBY.chomp
#       ->(__buffer__, __context__) do
#         __buffer__ << "<h1 class=\\"foot\\">foo</h1><h2 id=\\"bar\\" onclick=\\"f(&quot;abc&quot;, &quot;def&quot;)\\">bar</h2>"
#       end
#     RUBY
#     assert_equal expected, code

#     template_proc = compiled_template_proc(templ)
#     buffer = +''
#     template_proc.(buffer, nil)
#     assert_equal '<h1 class="foot">foo</h1><h2 id="bar" onclick="f(&quot;abc&quot;, &quot;def&quot;)">bar</h2>', buffer
#   end

#   def test_compiler_conditional_1
#     a = true
#     template = H {
#       h1 (a ? 'foo' : 'bar')
#     }

#     code = compiled_template_body(template)
#     assert_equal "__buffer__ << \"<h1>\#{__html_encode__(a ? \"foo\" : \"bar\")}</h1>\"\n", code
#   end

#   def test_compiler_conditional_2
#     a = true
#     template = H {
#       header 'hi'
#       a ? (p 'foo') : (h3 'bar')
#       footer 'bye'
#     }

#     code = compiled_template_body(template)
#     expected = <<~RUBY
#       __buffer__ << "<header>hi</header>"
#       if a
#         __buffer__ << "<p>foo</p>"
#       else
#         __buffer__ << "<h3>bar</h3>"
#       end
#       __buffer__ << "<footer>bye</footer>"
#     RUBY
#     assert_equal expected, code
#   end

#   def test_compiler_conditional_3
#     a = true
#     template = H {
#       h1 'hi' if a
#       h2 'bye' unless a
#     }

#     code = compiled_template_body(template)
#     expected = <<~RUBY
#       if a
#         __buffer__ << "<h1>hi</h1>"
#       end
#       unless a
#         __buffer__ << "<h2>bye</h2>"
#       end
#     RUBY
#     assert_equal expected, code
#   end

#   def test_compiler_conditional_4
#     a = true
#     b = true
#     template = H {
#       if a
#         h1 'foo'
#       elsif b
#         h2 'bar'
#       else
#         h3 'baz'
#       end
#     }

#     code = compiled_template_body(template)
#     expected = <<~RUBY
#       if a
#         __buffer__ << "<h1>foo</h1>"
#       else
#         if b
#           __buffer__ << "<h2>bar</h2>"
#         else
#           __buffer__ << "<h3>baz</h3>"
#         end
#       end
#     RUBY
#     assert_equal expected, code
#   end
# end

# class CompiledTemplateTest < MiniTest::Test
#   def test_compile
#     t = H { h1 'foo' }
#     c = t.compile

#     assert_kind_of Papercraft::Compiler, c
#     p = c.to_proc
#     b = +''
#     p.(b, nil)

#     assert_equal '<h1>foo</h1>', b
#   end

#   module ::Kernel
#     def C(**ctx, &block)
#       Papercraft.new(**ctx, &block).compile.tap { |c| puts '*' * 40; puts c.to_code; puts }.to_proc
#     end
#   end

#   class ::Proc
#     def render(context = {})
#       +''.tap { |b| call(b, context) }
#     end
#   end

#   def test_simple_html
#     h = C { div { p 'foo'; p 'bar' } }
#     assert_equal(
#       '<div><p>foo</p><p>bar</p></div>',
#       h.render
#     )
#   end

#   def test_that_attributes_are_supported_and_escaped
#     assert_equal(
#       '<div class="blue and green"/>',
#       C { div class: 'blue and green' }.render
#     )

#     assert_equal(
#       '<div onclick="return doit();"/>',
#       C { div onclick: 'return doit();' }.render
#     )

#     assert_equal(
#       '<a href="/?q=a%20b"/>',
#       C { a href: '/?q=a b' }.render
#     )
#   end

#   def test_that_valueless_attributes_are_supported
#     assert_equal(
#       '<input type="checkbox" checked/>',
#       C { input type: 'checkbox', checked: true }.render
#     )

#     assert_equal(
#       '<input type="checkbox"/>',
#       C { input type: 'checkbox', checked: false }.render
#     )
#   end

#   def test_that_tag_method_accepts_no_arguments
#     assert_equal(
#       '<div/>',
#       C { div() }.render
#     )
#   end

#   def test_that_tag_method_accepts_text_argument
#     assert_equal(
#       '<p>lorem ipsum</p>',
#       C { p "lorem ipsum" }.render
#     )
#   end

#   def test_that_tag_method_accepts_non_string_text_argument
#     assert_equal(
#       '<p>lorem</p>',
#       C { p :lorem }.render
#     )
#   end

#   def test_that_tag_method_escapes_string_text_argument
#     assert_equal(
#       '<p>lorem &amp; ipsum</p>',
#       C { p 'lorem & ipsum' }.render
#     )
#   end

#   def test_that_tag_method_accepts_text_and_attributes
#     assert_equal(
#       '<p class="hi">lorem ipsum</p>',
#       C { p "lorem ipsum", class: 'hi' }.render
#     )
#   end

#   # A1 = H { a 'foo', href: '/' }

#   # def test_that_tag_method_accepts_papercraft_argument
#   #   assert_equal(
#   #     '<p><a href="/">foo</a></p>',
#   #     C { p A1 }.render
#   #   )
#   # end

#   def test_that_tag_method_accepts_block
#     assert_equal(
#       '<div><p><a href="/">foo</a></p></div>',
#       C { div { p { a 'foo', href: '/' } } }.render
#     )
#   end
# end
