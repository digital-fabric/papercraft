module Papercraft
  module SoapComponents
    def Envelope(**props, &blk)
      props[:xmlns__soap] ||= 'http://schemas.xmlsoap.org/soap/envelope/'
      tag('soap:Envelope', **props, &blk)
    end

    def Header(**props, &blk)
      tag('soap:Header', **props, &blk)
    end

    def Body(**props, &blk)
      tag('soap:Body', **props, &blk)
    end

    def Fault(**props, &blk)
      tag('soap:Fault', **props, &blk)
    end
  end
end
