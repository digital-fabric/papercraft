# frozen_string_literal: true

require 'benchmark/ips'
require 'erb'

HeaderNonInterpolated = ->(__buffer__, title:) {
  __buffer__
    .<<("<header><h2 id=\"title\">")
    .<<(ERB::Escape.html_escape((title)))
    .<<("</h2><button>1</button><button>2</button></header>")
  __buffer__
}

ContentNonInterpolated = ->(__buffer__, title:) {
  __buffer__
    .<<("<article><h3>")
    .<<(ERB::Escape.html_escape((title)))
    .<<("</h3><p>Hello, world!</p><div><a href=\"http://google.com/?a=1&b=2&c=3 4\"><h3>foo bar</h3></a><p>lorem ipsum</p></div></article>")
  __buffer__
}

HeaderInterpolated = ->(__buffer__, title:) {
  __buffer__
    .<<("<header><h2 id=\"title\">#{ERB::Escape.html_escape((title))}</h2><button>1</button><button>2</button></header>")
  __buffer__
}

ContentInterpolated = ->(__buffer__, title:) {
  __buffer__
    .<<("<article><h3>#{ERB::Escape.html_escape((title))}</h3><p>Hello, world!</p><div><a href=\"http://google.com/?a=1&b=2&c=3 4\"><h3>foo bar</h3></a><p>lorem ipsum</p></div></article>")
  __buffer__
}

def render_non_interpolated(title:)
  __buffer__ = +''
  __buffer__.<<("<!DOCTYPE html><html><body>")
  HeaderNonInterpolated.(__buffer__, title:)
  ContentNonInterpolated.(__buffer__, title:)
  __buffer__.<<("</body></html>")
  __buffer__
end

def render_interpolated(title:)
  __buffer__ = +''
  __buffer__.<<("<!DOCTYPE html><html><body>")
  HeaderInterpolated.(__buffer__, title:)
  ContentInterpolated.(__buffer__, title:)
  __buffer__.<<("</body></html>")
  __buffer__
end

a = render_non_interpolated(title: 'foo')
b = render_interpolated(title: 'foo')

raise("Bad render") if a != b

Benchmark.ips do |x|
  x.report("non_interpolated") { render_non_interpolated(title: 'foo') }
  x.report("interpolated") { render_interpolated(title: 'foo') }

  x.compare!(order: :baseline)
end
