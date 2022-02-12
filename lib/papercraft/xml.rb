# frozen_string_literal: true

require 'escape_utils'
require_relative './tags'

module Papercraft  
  # XML renderer extensions
  module XML
    include Tags

    def tag_repr(tag)
      tag.to_s.gsub('__', ':').tr('_', '-')
    end

    # Catches undefined tag method call and handles it by defining the method.
    #
    # @param sym [Symbol] HTML tag or component identifier
    # @param args [Array] method arguments
    # @param opts [Hash] named method arguments
    # @param &block [Proc] block passed to method
    # @return [void]
    def method_missing(sym, *args, **opts, &block)
      tag = sym.to_s
      tag_repr = tag_repr(tag)
      code = S_TAG_METHOD % {
        tag: tag,
        TAG: tag.upcase,
        tag_pre: "<#{tag_repr}".inspect,
        tag_close: "</#{tag_repr}>".inspect
      }
      self.class.class_eval(code, __FILE__, S_TAG_METHOD_LINE)
      send(sym, *args, **opts, &block)
    end

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

      tag = sym.to_s.gsub('__', ':').tr('_', '-')

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

    private

    # Escapes the given text using XML entities.
    def escape_text(text)
      EscapeUtils.escape_xml(text.to_s)
    end
  end
end
