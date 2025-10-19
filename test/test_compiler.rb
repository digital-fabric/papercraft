# frozen_string_literal: true

require_relative './helper'
require_relative '../lib/papercraft/compiler'

class CompilerTest < Minitest::Test
  Dir["#{FIXTURES_PATH}/compiler/*_source.rb"].each do |fn|
    basename = File.basename(fn)
    test_name = basename.match(/^(.+)_source\.rb$/)[1]
    html_fn = File.join(FIXTURES_PATH, "compiler/#{test_name}.html")

    original_src = IO.read(fn).chomp
    html = IO.read(html_fn)

    define_method(:"test_compiler_#{test_name}") do
      proc = eval(original_src, binding, fn)
      node = Sirop.to_ast(proc) { |str| }
      assert_kind_of Prism::Node, node

      if ENV['DEBUG'] == '1'
        p node
        _source_map, compiled_code = Papercraft::Compiler.compile_to_code(proc)

        puts '=' * 40
        puts compiled_code
      end

      assert_equal html, Papercraft.html(proc)
    end
  end
end
