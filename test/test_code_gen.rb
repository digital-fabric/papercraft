# frozen_string_literal: true

__END__

require 'bundler/setup'
require 'p2'

header = ->(foo) {
  div(class: 'header') {
    button foo
    button 2
  }
}

t = -> {
  body {
    render header, 'bar'
  }
}

puts t.compiled_code(compiler_class: P2::DirectInvocationTemplateCompiler)
puts
puts t.render
puts

__END__


->(__buffer__) do
  hdr.compiled_proc.(__buffer__, foo: 'bar'), &(
    ->(__buffer__) {
      __buffer__ << "<button>hi</button>"
    }.compiled!
  ); __buffer__
    rescue Exception => e; P2.translate_backtrace(e, src_map); raise e; end