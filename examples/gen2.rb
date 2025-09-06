# frozen_string_literal: true

require 'erb'
require 'benchmark/ips'

def erubi(title:)
  _buf = +'';;
  _buf <<
    '<article><h3>' <<
    ( ERB::Escape.html_escape(title) ).to_s <<
    '</h3><p>Hello, world!</p><div><a href="' <<
    ( 'http://google.com/?a=1&b=2&c=3%204' ).to_s <<
    '"><h3>foo bar</h3></a><p>lorem ipsum</p></div></article>'
end

def erb(title:)
_erbout = +'';
_erbout.<< "<article>\n  <h3>".freeze
; _erbout.<<(( ERB::Escape.html_escape(title) ).to_s);
_erbout.<< "</h3>\n  <p>Hello, world!</p>\n  <div>\n    <a href=\"".freeze
; _erbout.<<(( 'http://google.com/?a=1&b=2&c=3%204' ).to_s);
_erbout.<< "\">\n      <h3>foo bar</h3>\n    </a>\n    <p>lorem ipsum</p>\n  </div>\n</article>\n".freeze
; _erbout
end

def p2(__buffer__, title:)
  ; __buffer__  << "<article><h3>"
    ; __buffer__  << ERB::Escape.html_escape((title)) << "</h3><p>Hello, world!</p><div><a href=\"http://google.com/?a=1&b=2&c=3 4\"><h3>foo bar</h3></a><p>lorem ipsum</p></div></article>"; __buffer__
end

puts erubi(title: 'foo')
puts
puts erb(title: 'foo')
puts
puts p2(+'', title: 'foo')
puts



Benchmark.ips do |x|
  x.report("erubi") { erubi(title: 'foo') }
  x.report("erb")   { erb(title: 'foo') }
  x.report("p2")    { p2(+'', title: 'foo') }

  x.compare!(order: :baseline)
end
