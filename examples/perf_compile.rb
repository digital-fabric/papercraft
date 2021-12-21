require 'bundler/setup'
require 'papercraft'
require 'escape_utils'
require 'benchmark/ips'

content = 'foo'

T = H {
  html5 {
    head {
      title 'some title'
      meta charset: 'utf-8'
      meta name: 'viewport', content: 'width=device-width, initial-scale=1.0'
      meta name: 'referrer', content: 'no-referrer'
      style 'body { display: none }' # prevent FUOC
      link rel: 'icon', type: 'image/png', href: '/assets/nf-icon-black.png'
      link rel: 'stylesheet', type: 'text/css', href: '/assets/style.css'
      link rel: 'alternate', type: 'application/rss+xml', href: '/feeds/rss'
    }
    body {
      header {
        h1 {
          a(href: '/') {
            img src: '/assets/nf-icon-black.png'
            span 'noteflakes'
          }
        }
        ul {
          li 'by Sharon Rosner', class: 'byline'
          li { a 'archive', href: '/archive' }
          li { a 'about', href: '/about' }
          li { a 'RSS feed', href: '/feeds/rss' }
          li { a 'code', href: 'https://github.com/ciconia', target: '_blank' }
        }
      }
      div content, id: 'content'
      footer {
        hr
        p {
          span 'Copyright © 2021 Sharon Rosner. This site runs on '
          a 'Impression', href: 'https://github.com/digital-fabric/impression'
          span ' and '
          a 'Tipi', href: 'https://github.com/digital-fabric/tipi'
          span '.'
        }
      }
    }
  }
}

class Renderer
  def render_template
    T.render
  end

  def render_compiled_template
    @compiled ||= T.compile.to_proc
    buffer = String.new(capacity: 1024)
    @compiled.(buffer, {})
  end
end

r = Renderer.new

puts r.render_template
puts
puts r.render_compiled_template

puts "=== Template with 2 partials"
Benchmark.ips do |x|
  x.config(:time => 3, :warmup => 1)

  x.report("normal") { r.render_template }
  x.report("compiled") { r.render_compiled_template }

  x.compare!
end
