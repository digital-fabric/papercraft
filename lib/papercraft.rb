# frozen_string_literal: true

require 'escape_utils'

require_relative 'papercraft/component'
require_relative 'papercraft/renderer'
require_relative 'papercraft/encoding'
# require_relative 'papercraft/compiler'

# Papercraft is a component-based HTML templating library
module Papercraft
  # Exception class used to signal templating-related errors
  class Error < RuntimeError; end

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
  def self.extension(map)
    Renderer.extension(map)
  end
end

# Kernel extensions
module ::Kernel
  
  # Creates a new papercraft component. `#H` can take either a proc argument or
  # a block. In both cases, the proc is converted to a `Papercraft::Component`.
  #
  # H(proc { h1 'hi' }).render #=> "<h1>hi</h1>"
  # H { h1 'hi' }.render #=> "<h1>hi</h1>"
  #
  # @param template [Proc] template block
  # @return [Papercraft::Component] Papercraft component
  def H(o = nil, &template)
    return o if o.is_a?(Papercraft::Component)
    template ||= o
    Papercraft::Component.new(mode: :html, &template)
  end

  # Creates a new papercraft component in XML mode. `#X` can take either a proc argument or
  # a block. In both cases, the proc is converted to a `Papercraft::Component`.
  #
  # X(proc { item 'foo' }).render #=> "<item>foo</item>"
  # X { item 'foo' }.render #=> "<item>foo</item>"
  #
  # @param template [Proc] template block
  # @return [Papercraft::Component] Papercraft component
  def X(o = nil, &template)
    return o if o.is_a?(Papercraft::Component)
    template ||= o
    Papercraft::Component.new(mode: :xml, &template)
  end
end
