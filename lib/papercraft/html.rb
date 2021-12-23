# frozen_string_literal: true

require 'kramdown'
require 'rouge'
require 'kramdown-parser-gfm'

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

    def emit_markdown(markdown, **opts)
      emit Kramdown::Document.new(markdown, **kramdown_options(opts)).to_html
    end

    def kramdown_options(opts)
      HTML.kramdown_options.merge(**opts)
    end

    class << self
      def kramdown_options
        @kramdown_options ||= {
          entity_output: :numeric,
          syntax_highlighter: :rouge,
          input: 'GFM',
          hard_wrap: false  
        }
      end

      def kramdown_options=(opts)
        @kramdown_options = opts
      end
    end
  end
end
