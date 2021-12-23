# frozen_string_literal: true

require_relative './html'

module Papercraft
  
  # HTML Markup extensions
  module HTML
    # Emits the p tag (overrides Object#p)
    #
    # @param text [String] text content of tag
    # @param props [Hash] tag attributes
    # @para block [Proc] nested HTML block
    # @return [void]
    def p(text = nil, **props, &block)
      method_missing(:p, text, **props, &block)
    end

    S_HTML5_DOCTYPE = '<!DOCTYPE html>'

    # Emits an HTML5 doctype tag and an html tag with the given block.
    #
    # @param block [Proc] nested HTML block
    # @return [void]
    def html5(&block)
      @buffer << S_HTML5_DOCTYPE
      self.html(&block)
    end

    # Emits a link element with a stylesheet.
    #
    # @param href [String] stylesheet URL
    # @param custom_attributes [Hash] optional custom attributes for the link element
    # @return [void]
    def link_stylesheet(href, custom_attributes = nil)
      attributes = {
        rel: 'stylesheet',
        href: href
      }
      if custom_attributes
        attributes = custom_attributes.merge(attributes)
      end
      link(**attributes)
    end
  end
end
