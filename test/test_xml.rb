# frozen_string_literal: true

require 'bundler/setup'
require 'minitest/autorun'
require 'time'
require 'papercraft'

class HtmlTest < Minitest::Test
  def test_rss_generation
    entries = [
      {
        title:  'foo',
        url:    '/01-foo',
        date:   'Tue, 01 Jan 2025',
        markdown: '# Foo & Bar'
      },
      {
        title:  'bar',
        url:    '/02-bar',
        date:   'Sat, 02 Feb 2025',
        markdown: '# Bar & Baz'
      },
    ]

    t = -> {
      rss(version: '2.0', 'xmlns:atom' => 'http://www.w3.org/2005/Atom') {
        channel {
          title 'Foo'
          link 'https://foo.com/'
          description 'Foo RSS'
          language 'en-us'
          pubDate 'Thu, 11 Sep 2025 08:00:00 GMT'
          raw '<atom:link href="https://noteflakes.com/feeds/rss" rel="self" type="application/rss+xml" /> '

          entries.each { |e|
            item {
              title e[:title]
              link "https://noteflakes.com#{e[:url]}"
              guid "https://noteflakes.com#{e[:url]}"
              pubDate "#{e[:date]} 00:00:00 GMT"
              description Papercraft.markdown(e[:markdown]).chomp
            }
          }
        }
      }
    }

    expected = '<rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom"><channel><title>Foo</title><link>https://foo.com/</link><description>Foo RSS</description><language>en-us</language><pubDate>Thu, 11 Sep 2025 08:00:00 GMT</pubDate><atom:link href="https://noteflakes.com/feeds/rss" rel="self" type="application/rss+xml" /> <item><title>foo</title><link>https://noteflakes.com/01-foo</link><guid>https://noteflakes.com/01-foo</guid><pubDate>Tue, 01 Jan 2025 00:00:00 GMT</pubDate><description>&lt;h1 id=&quot;foo--bar&quot;&gt;Foo &amp;amp; Bar&lt;/h1&gt;</description></item><item><title>bar</title><link>https://noteflakes.com/02-bar</link><guid>https://noteflakes.com/02-bar</guid><pubDate>Sat, 02 Feb 2025 00:00:00 GMT</pubDate><description>&lt;h1 id=&quot;bar--baz&quot;&gt;Bar &amp;amp; Baz&lt;/h1&gt;</description></item></channel></rss>'
    assert_equal expected, Papercraft.xml(t)
  end
end
