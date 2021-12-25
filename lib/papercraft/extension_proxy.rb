# frozen_string_literal: true

module Papercraft
  
  # An ExtensionProxy proxies method calls to a renderer. Extension proxies are
  # used to provide an namespaced interface to Papercraft extensions. When an
  # extension is installed using `Papercraft.extension`, a corresponding method
  # is defined on the `Papercraft::Renderer` class that creates an extension
  # proxy that gives access to the different extension methods.
  class ExtensionProxy

    # Initializes a new ExtensionProxy.
    # @param renderer [Papercraft::Renderer] renderer to proxy to
    # @param mod [Module] extension module
    # @return [void]
    def initialize(renderer, mod)
      @renderer = renderer
      extend(mod)
    end
  
    # Proxies missing methods to the renderer
    # @param sym [Symbol] method name
    # @param *args [Array] arguments
    # @param &block [Proc] block
    # @return void
    def method_missing(sym, *args, &block)
      @renderer.send(sym, *args, &block)
    end
  end
end
