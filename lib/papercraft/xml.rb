# frozen_string_literal: true

require_relative './tags'
require 'escape_utils'

module Papercraft
  # XML renderer extensions
  module XML
    include Tags

    private

    # Returns false (no void elements in XML)
    #
    # @param tag [String] tag
    # @return [false] false
    def is_void_element_tag?(tag)
      false
    end

      # Converts a tag to its string representation. Underscores will be converted
    # to dashes, double underscores will be converted to colon.
    #
    # @param tag [Symbol, String] tag
    # @return [String] tag string
    def tag_repr(tag)
      tag.to_s.gsub('__', ':').tr('_', '-')
    end

    # Converts an attribute to its string representation. Underscores will be
    # converted to dashes, double underscores will be converted to colon.
    #
    # @param att [Symbol, String] attribute
    # @return [String] attribute string
    def att_repr(att)
      att.to_s.gsub('__', ':').tr('_', '-')
    end

    # Escapes the given text using XML entities.
    #
    # @param text [String] text
    # @return [String] escaped text
    def escape_text(text)
      EscapeUtils.escape_xml(text.to_s)
    end
  end
end
