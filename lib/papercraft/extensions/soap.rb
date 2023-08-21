# frozen_string_literal: true

module Papercraft
  module Extensions
    module Soap
      # Emits a SOAP XML tag that identifies the XML document as a SOAP message.
      #
      # @param **props [Hash] tag attributes
      # @return [void]
      def Envelope(**props, &block)
        props[:xmlns__soap] ||= 'http://schemas.xmlsoap.org/soap/envelope/'
        tag('soap:Envelope', **props, &block)
      end

      # Emits a SOAP XML tag that contains header information.
      #
      # @param **props [Hash] tag attributes
      # @return [void]
      def Header(**props, &blk)
        tag('soap:Header', **props, &blk)
      end

      # Emits a SOAP XML tag that contains header information.
      #
      # @param **props [Hash] tag attributes
      # @return [void]
      def Body(**props, &blk)
        tag('soap:Body', **props, &blk)
      end

      # Emits a SOAP XML tag that contains errors and status information.
      #
      # @param **props [Hash] tag attributes
      # @return [void]
      def Fault(**props, &blk)
        tag('soap:Fault', **props, &blk)
      end
    end
  end
end

Papercraft.extension(soap: Papercraft::Extensions::Soap)
