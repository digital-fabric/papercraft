# frozen_string_literal: true

require_relative './helper'
require_relative '../lib/papercraft/compiler'

class CompilerTest < Minitest::Test
  Dir["#{FIXTURES_PATH}/compiler/*_source.rb"].each do |fn|
    basename = File.basename(fn)
    test_name = basename.match(/^(.+)_source\.rb$/)[1]
    compiled_fn = File.join(FIXTURES_PATH, "compiler/#{test_name}_compiled.rb")
    html_fn = File.join(FIXTURES_PATH, "compiler/#{test_name}.html")

    original_src = IO.read(fn).chomp
    compiled_src = IO.read(compiled_fn).chomp
    html = IO.read(html_fn)

    define_method(:"test_compile_#{test_name}") do
      proc = eval(original_src, binding, fn)
      node = Sirop.to_ast(proc) { |str| }
      assert_kind_of Prism::Node, node

      p node if ENV['DEBUG'] == '1'
      compiled_code = Papercraft::Compiler.new.compile(node)
      puts compiled_code if ENV['DEBUG'] == '1'

      # render source proc
      assert_equal html, Papercraft.html(&proc).render
      
      # compile
      assert_equal compiled_src, compiled_code

      compiled_proc = eval(compiled_code, proc.binding)
      compiled_html = +''
      compiled_proc.call(compiled_html)

      # render compiled proc
      assert_equal html, compiled_html
    end
  end
end
