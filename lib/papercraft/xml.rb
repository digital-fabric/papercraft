# frozen_string_literal: true

require 'escape_utils'
require_relative './tags'

module Papercraft  
  # XML renderer extensions
  module XML
    include Tags

    private

    def tag_repr(tag)
      tag.to_s.gsub('__', ':').tr('_', '-')
    end

    def att_repr(att)
      att.to_s.gsub('__', ':').tr('_', '-')
    end

    # Escapes the given text using XML entities.
    def escape_text(text)
      EscapeUtils.escape_xml(text.to_s)
    end
  end
end
