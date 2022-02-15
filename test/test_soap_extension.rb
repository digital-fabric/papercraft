# frozen_string_literal: true

require 'bundler/setup'
require 'minitest/autorun'
require 'papercraft'
require 'papercraft/extensions/soap'

class SoapExtensionTest < MiniTest::Test
  def test_soap_extension
    xml = Papercraft.xml {
      soap.Envelope(
        xmlns__xsd: 'http://www.w3.org/2001/XMLSchema',
        xmlns__xsi: 'http://www.w3.org/2001/XMLSchema-instance'
      ) {
        soap.Body {
          PosRequest(xmlns: 'http://Some.Site') {
            tag('Ver1.0') {
              Header {
                SecretAPIKey 'some_secret_key'
              }
              Transaction {
                SomeData {}
              }
            }
          }
        }
      }
    }

    assert_equal(
      '<soap:Envelope xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"><soap:Body><PosRequest xmlns="http://Some.Site"><Ver1.0><Header><SecretAPIKey>some_secret_key</SecretAPIKey></Header><Transaction><SomeData></SomeData></Transaction></Ver1.0></PosRequest></soap:Body></soap:Envelope>'.gsub('<', '\n<'),
      xml.render.gsub('<', '\n<')
    )
  end
end
