# frozen_string_literal: true

require 'bundler/setup'
require 'minitest/autorun'
require 'p2'

FIXTURES_PATH = File.join(__dir__, 'fixtures')

module Kernel
  def load_code(name)
    fn = File.join(EXAMPLES_PATH, "#{name}.rb")
    eval(IO.read(fn), binding, fn)
  end
end
