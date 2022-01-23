# frozen_string_literal: true

require 'bundler/setup'
require 'minitest/autorun'
require 'papercraft'

class XmlTest < MiniTest::Test
  def test_xml_method_with_block
    block = proc { :foo }
    x = Papercraft.xml(&block)

    assert_kind_of(Papercraft::Component, x)
    assert_equal :xml, x.mode
    assert_equal :foo, x.call
  end

  def test_xml_method_with_argument
    o = proc { :foo }
    x = Papercraft.xml(o)

    assert_kind_of(Papercraft::Component, x)
    assert_equal :xml, x.mode
    assert_equal :foo, x.call

    x2 = Papercraft.xml(x)
    assert_equal x2, x
  end

  def test_generic_xml
    xml = Papercraft.xml {
      rss(version: '2.0') {
        channel {
          item 'foo'
          item 'bar'
        }
      }
    }

    assert_equal(
      '<rss version="2.0"><channel><item>foo</item><item>bar</item></channel></rss>',
      xml.render
    )
  end

  def test_xml_encoding
    xml = Papercraft.xml {
      link 'http://liftoff.msfc.nasa.gov/news/2003/news-starcity.asp'
    }

    assert_equal(
      '<link>http://liftoff.msfc.nasa.gov/news/2003/news-starcity.asp</link>',
      xml.render
    )
  end
end
