# frozen_string_literal: true

require 'bundler/setup'
require 'minitest/autorun'
require 'papercraft'

class XmlTest < Minitest::Test
  def test_xml_method_with_block
    block = proc { :foo }
    x = Papercraft.xml(&block)

    assert_kind_of(Papercraft::Template, x)
    assert_equal :xml, x.mode
    assert_equal :foo, x.call
  end

  def test_xml_method_with_argument
    o = proc { :foo }
    x = Papercraft.xml(o)

    assert_kind_of(Papercraft::Template, x)
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

  def test_xml_capitalized_tags
    xml = Papercraft.xml {
      Foo {
        Bar 42
      }
    }

    assert_equal(
      '<Foo><Bar>42</Bar></Foo>', xml.render
    )
  end

  def test_xml_namespaced_tags
    xml = Papercraft.xml {
      soap__Envelope 'hi'
    }
    assert_equal(
      '<soap:Envelope>hi</soap:Envelope>',
      xml.render
    )
  end

  def test_soap_issue_9
    xml = Papercraft.xml {
      soap__Envelope(
        xmlns__soap:  'http://schemas.xmlsoap.org/soap/envelope/',
        xmlns__xsd: 'http://www.w3.org/2001/XMLSchema',
        xmlns__xsi: 'http://www.w3.org/2001/XMLSchema-instance'
      ) {
        soap__Body {
          PosRequest(xmlns: 'http://Some.Site') {
            tag('Ver1.0') {
              Header {
                SecretAPIKey 'some_secret_key'
              }
              Transaction {
                SomeData { }
              }
            }
          }
        }
      }
    }

    assert_equal(
      '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"><soap:Body><PosRequest xmlns="http://Some.Site"><Ver1.0><Header><SecretAPIKey>some_secret_key</SecretAPIKey></Header><Transaction><SomeData></SomeData></Transaction></Ver1.0></PosRequest></soap:Body></soap:Envelope>'.gsub('<', '\n<'),
      xml.render.gsub('<', '\n<')
    )
  end
end
