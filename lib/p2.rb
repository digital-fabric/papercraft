# frozen_string_literal: true

require_relative 'p2/template'
require_relative 'p2/renderer'
# require_relative 'p2/compiler'

# P2 is a composable templating library
module P2
  # Exception class used to signal templating-related errors
  class Error < RuntimeError; end

  class << self

    # Creates a new p2 template. `P2.html` can take either a proc
    # argument or a block. In both cases, the proc is converted to a
    # `P2::Template`.
    #
    # P2.html(proc { h1 'hi' }).render #=> "<h1>hi</h1>"
    # P2.html { h1 'hi' }.render #=> "<h1>hi</h1>"
    #
    # @param template [Proc] template block
    # @return [P2::Template] P2 template
    def html(o = nil, &template)
      return o if o.is_a?(P2::Template)
      template ||= o
      P2::Template.new(mode: :html, &template)
    end

    # Renders Markdown into HTML. The `opts` argument will be merged with the
    # default Kramdown options in order to change the rendering behaviour.
    #
    # @param markdown [String] Markdown
    # @param opts [Hash] Kramdown option overrides
    # @return [String] HTML
    def markdown(markdown, **opts)
      # require relevant deps on use
      require 'kramdown'
      require 'rouge'
      require 'kramdown-parser-gfm'
      
      opts = default_kramdown_options.merge(opts)
      Kramdown::Document.new(markdown, **opts).to_html
    end

    # Returns the default Kramdown options used for rendering Markdown.
    #
    # @return [Hash] Kramdown options
    def default_kramdown_options
      @default_kramdown_options ||= {
        entity_output: :numeric,
        syntax_highlighter: :rouge,
        input: 'GFM',
        hard_wrap: false
      }
    end

    # Sets the default Kramdown options used for rendering Markdown.
    #
    # @param opts [Hash] Kramdown options
    # @return [void]
    def default_kramdown_options=(opts)
      @default_kramdown_options = opts
    end
  end
end
