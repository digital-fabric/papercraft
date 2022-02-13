# frozen_string_literal: true

module Papercraft  
  # Markup (HTML/XML) extensions
  module Tags
    S_LT              = '<'
    S_GT              = '>'
    S_LT_SLASH        = '</'
    S_SPACE_LT_SLASH  = ' </'
    S_SLASH_GT        = '/>'
    S_SPACE           = ' '
    S_EQUAL_QUOTE     = '="'
    S_QUOTE           = '"'

    # The tag method template below is optimized for performance. Do not touch!

    S_TAG_METHOD_LINE = __LINE__ + 2
    S_TAG_METHOD = <<~EOF
      S_TAG_%<TAG>s_PRE = %<tag_pre>s
      S_TAG_%<TAG>s_CLOSE = %<tag_close>s

      def %<tag>s(text = nil, **props, &block)
        if text.is_a?(Hash) && props.empty?
          props = text
          text = nil
        end

        @buffer << S_TAG_%<TAG>s_PRE
        emit_props(props) unless props.empty?

        if block
          @buffer << S_GT
          instance_eval(&block)
          @buffer << S_TAG_%<TAG>s_CLOSE
        elsif Proc === text
          @buffer << S_GT
          emit(text)
          @buffer << S_TAG_%<TAG>s_CLOSE
        elsif text
          @buffer << S_GT << escape_text(text.to_s) << S_TAG_%<TAG>s_CLOSE
        else
          @buffer << S_SLASH_GT
        end
      end
    EOF

    # Emits an XML tag with the given content, properties and optional block.
    # This method is an alternative to emitting XML tags using dynamically
    # created methods. This is particularly useful when using extensions that
    # have method names that clash with XML tags, such as `button` or `a`, or
    # when you need to override the behaviour of a particular XML tag.
    #
    # The following two method calls have the same effect:
    #
    # button 'text', id: 'button1'
    # tag :button, 'text', id: 'button1'
    #
    # @param sym [Symbol, String] XML tag
    # @param text [String, nil] tag content
    # @param **props [Hash] tag attributes
    # @param &block [Proc] optional inner XML
    # @return [void]
    def tag(sym, text = nil, **props, &block)
      if text.is_a?(Hash) && props.empty?
        props = text
        text = nil
      end

      tag = tag_repr(sym)

      @buffer << S_LT << tag
      emit_props(props) unless props.empty?

      if block
        @buffer << S_GT
        instance_eval(&block)
        @buffer << S_LT_SLASH << tag << S_GT
      elsif Proc === text
        @buffer << S_GT
        emit(text)
        @buffer << S_LT_SLASH << tag << S_GT
      elsif text
        @buffer << S_GT << escape_text(text.to_s) << S_LT_SLASH << tag << S_GT
      else
        @buffer << S_SLASH_GT
      end
    end

    # Catches undefined tag method call and handles it by defining the method.
    #
    # @param sym [Symbol] XML tag or component identifier
    # @param args [Array] method arguments
    # @param opts [Hash] named method arguments
    # @param &block [Proc] block passed to method
    # @return [void]
    def method_missing(sym, *args, **opts, &block)
      # p method_missing: sym, self: self
      tag = sym.to_s
      repr = tag_repr(tag)
      code = S_TAG_METHOD % {
        tag: tag,
        TAG: tag.upcase,
        tag_pre: "<#{repr}".inspect,
        tag_close: "</#{repr}>".inspect
      }
      self.class.class_eval(code, __FILE__, S_TAG_METHOD_LINE)
      send(sym, *args, **opts, &block)
    end

    # Emits text into the rendering buffer, escaping any special characters to
    # the respective XML entities.
    #
    # @param data [String] text
    # @return [void]
    def text(data)
      @buffer << escape_text(data)
    end

    private

    def tag_repr(tag)
      tag.to_s.tr('_', '-')
    end

    def att_repr(att)
      att.to_s.tr('_', '-')
    end

    # Emits tag attributes into the rendering buffer
    # @param props [Hash] tag attributes
    # @return [void]
    def emit_props(props)
      props.each { |k, v|
        case k
        when :src, :href
          @buffer << S_SPACE << k.to_s << S_EQUAL_QUOTE <<
            EscapeUtils.escape_uri(v) << S_QUOTE
        else
          case v
          when true
            @buffer << S_SPACE << att_repr(k)
          when false, nil
            # emit nothing
          else
            @buffer << S_SPACE << att_repr(k) <<
              S_EQUAL_QUOTE << v << S_QUOTE
          end
        end
      }
    end
  end
end
