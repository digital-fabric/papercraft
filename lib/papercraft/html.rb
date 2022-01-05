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

    # Emits an inline CSS style element.
    #
    # @param css [String] CSS code
    # @param **props [Hash] optional element attributes
    # @return [void]
    def style(css, **props, &block)
      @buffer << '<style'
      emit_props(props) unless props.empty?

      @buffer << '>' << css << '</style>'
    end
  
    # Emits an inline JS script element.
    #
    # @param js [String, nil] Javascript code
    # @param **props [Hash] optional element attributes
    # @return [void]
    def script(js = nil, **props, &block)
      @buffer << '<script'
      emit_props(props) unless props.empty?

      if js
        @buffer << '>' << js << '</script>'
      else
        @buffer << '></script>'
      end
    end
  
    # Converts and emits the given markdown. Papercraft uses
    # [Kramdown](https://github.com/gettalong/kramdown/) to do the Markdown to
    # HTML conversion. Optional Kramdown settings can be provided in order to
    # control the conversion. Those are merged with the default Kramdown
    # settings, which can be controlled using
    # `Papercraft::HTML.kramdown_options`.
    #
    # @param markdown [String] Markdown content
    # @param **opts [Hash] Kramdown options
    # @return [void]
    def emit_markdown(markdown, **opts)
      emit Kramdown::Document.new(markdown, **kramdown_options(opts)).to_html
    end

    class << self
      # Returns the default Kramdown options used for converting Markdown to
      # HTML.
      #
      # @return [Hash] Default Kramdown options
      def kramdown_options
        @kramdown_options ||= {
          entity_output: :numeric,
          syntax_highlighter: :rouge,
          input: 'GFM',
          hard_wrap: false  
        }
      end

      # Sets the default Kramdown options used for converting Markdown to
      # HTML.
      #
      # @param opts [Hash] New deafult Kramdown options
      # @return [Hash] New default Kramdown options
      def kramdown_options=(opts)
        @kramdown_options = opts
      end
    end

    private

    # Returns the default Kramdown options, merged with the given overrides.
    # 
    # @param opts [Hash] Kramdown option overrides
    # @return [Hash] Merged Kramdown options
    def kramdown_options(opts)
      HTML.kramdown_options.merge(**opts)
    end
  end
end
