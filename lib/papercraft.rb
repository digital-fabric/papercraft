# frozen_string_literal: true

require 'kramdown'
require 'rouge'
require 'kramdown-parser-gfm'

require_relative 'papercraft/template'
require_relative 'papercraft/renderer'
require_relative 'papercraft/encoding'
# require_relative 'papercraft/compiler'


# Papercraft is a composable templating library
module Papercraft
  # Exception class used to signal templating-related errors
  class Error < RuntimeError; end
  
  class << self
    
    # Installs one or more extensions. Extensions enhance templating capabilities
    # by adding namespaced methods to emplates. An extension is implemented as a
    # Ruby module containing one or more methods. Each method in the extension
    # module can be used to render a specific HTML element or a set of elements.
    #
    # This is a convenience method. For more information on using Papercraft
    # extensions, see `Papercraft::Renderer::extension`
    #
    # @param map [Hash] hash mapping methods to extension modules
    # @return [void]
    def extension(map)
      Renderer.extension(map)
    end
    
    # Creates a new papercraft template. `Papercraft.html` can take either a proc
    # argument or a block. In both cases, the proc is converted to a
    # `Papercraft::Template`.
    #
    # Papercraft.html(proc { h1 'hi' }).render #=> "<h1>hi</h1>"
    # Papercraft.html { h1 'hi' }.render #=> "<h1>hi</h1>"
    #
    # @param template [Proc] template block
    # @return [Papercraft::Template] Papercraft template
    def html(o = nil, mime_type: nil, &template)
      return o if o.is_a?(Papercraft::Template)
      template ||= o
      Papercraft::Template.new(mode: :html, mime_type: mime_type, &template)
    end
    
    # Creates a new Papercraft template in XML mode. `Papercraft.xml` can take
    # either a proc argument or a block. In both cases, the proc is converted to a
    # `Papercraft::Template`.
    #
    # Papercraft.xml(proc { item 'foo' }).render #=> "<item>foo</item>"
    # Papercraft.xml { item 'foo' }.render #=> "<item>foo</item>"
    #
    # @param template [Proc] template block
    # @return [Papercraft::Template] Papercraft template
    def xml(o = nil, mime_type: nil, &template)
      return o if o.is_a?(Papercraft::Template)
      template ||= o
      Papercraft::Template.new(mode: :xml, mime_type: mime_type, &template)
    end
    
    # Creates a new Papercraft template in JSON mode. `Papercraft.json` can take
    # either a proc argument or a block. In both cases, the proc is converted to a
    # `Papercraft::Template`.
    #
    # Papercraft.json(proc { item 42 }).render #=> "[42]"
    # Papercraft.json { foo 'bar' }.render #=> "{\"foo\": \"bar\"}"
    #
    # @param template [Proc] template block
    # @return [Papercraft::Template] Papercraft template
    def json(o = nil, mime_type: nil, &template)
      return o if o.is_a?(Papercraft::Template)
      template ||= o
      Papercraft::Template.new(mode: :json, mime_type: mime_type, &template)
    end

    # Renders Markdown into HTML. The `opts` argument will be merged with the
    # default Kramdown options in order to change the rendering behaviour.
    #
    # @param markdown [String] Markdown
    # @param **opts [Hash] Kramdown option overrides
    # @return [String] HTML
    def markdown(markdown, **opts)
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
