# frozen_string_literal: true

require 'escape_utils'
require_relative './tags'
require_relative './soap'

module Papercraft  
  # XML renderer extensions
  module XML
    include Tags

    private

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
