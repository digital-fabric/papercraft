# frozen_string_literal: true

require_relative './html'

module Papercraft

  # Component represents a distinct, reusable HTML template. A component can
  # include other components, and also be nested inside other components.
  #
  # Since in Papercraft HTML is expressed using blocks (or procs,) the Component
  # class is simply a special kind of Proc, which has some enhanced
  # capabilities, allowing it to be easily composed in a variety of ways.
  #
  # Components are usually created using the global methods `H` or `X`, for HTML
  # or XML templates, respectively:
  #
  #   greeter = H { |name| h1 "Hello, #{name}!" }
  #   greeter.render('world') #=> "<h1>Hello, world!</h1>"
  #
  # Components can also be created using the normal constructor:
  #
  #   greeter = Papercraft::Component.new { |name| h1 "Hello, #{name}!" }
  #   greeter.render('world') #=> "<h1>Hello, world!</h1>"
  #
  # In the component block, HTML elements are created by simply calling
  # unqualified methods:
  #
  #   page_layout = H {
  #     html5 {
  #       head {
  #         title 'foo'
  #       }
  #       body {
  #         h1 "Hello, world!"
  #       }
  #     }
  #   }
  #
  # Papercraft components can take explicit parameters in order to render
  # dynamic content. This can be in the form of regular or named parameters. The
  # `greeter` template shown above takes a single `name` parameter. Here's how a
  # anchor component could be implemented with named parameters:
  #
  #   anchor = H { |uri: , text: | a(text, href: uri) }
  #
  # The above component could later be rendered by passing the needed arguments:
  #
  #   anchor.render(uri: 'https://example.com', text: 'Example')
  #
  # ## Component Composition
  #
  # A component can be included in another component using the `emit` method:
  #
  #   links = H {
  #     emit anchor, uri: '/posts',   text: 'Posts'
  #     emit anchor, uri: '/archive', text: 'Archive'
  #     emit anchor, uri: '/about',   text: 'About'
  #   }
  #
  # Another way of composing components is to pass the components themselves as
  # parameters:
  #
  #   links = H { |anchors|
  #     anchors.each { |a| emit a }
  #   }
  #   links.render([
  #     anchor.apply(uri: '/posts', text: 'Posts'),
  #     anchor.apply(uri: '/archive', text: 'Archive'),
  #     anchor.apply(uri: '/about', text: 'About')
  #   ])
  #
  # The `#apply` method creates a new component, applying the given parameters
  # such that the component can be rendered without parameters:
  #
  #   links_with_anchors = links.apply([
  #     anchor.apply(uri: '/posts', text: 'Posts'),
  #     anchor.apply(uri: '/archive', text: 'Archive'),
  #     anchor.apply(uri: '/about', text: 'About')
  #   ])
  #   links_with_anchors.render
  #
  class Component < Proc
    
    # Determines the rendering mode: `:html` or `:xml`.
    attr_accessor :mode

    # Initializes a component with the given block. The rendering mode (HTML or
    # XML) can be passed in the `mode:` parameter. If `mode:` is not specified,
    # the component defaults to HTML.
    #
    # @param mode [:html, :xml] rendering mode
    # @param block [Proc] nested HTML block
    def initialize(mode: :html, &block)
      @mode = mode
      super(&block)
    end
  
    H_EMPTY = {}.freeze
  
    # Renders the template with the given parameters and or block, and returns
    # the string result.
    #
    # @param context [Hash] context
    # @return [String]
    def render(*a, **b, &block)
      template = self
      Renderer.verify_proc_parameters(template, a, b)
      renderer_class.new do
        if block
          with_block(block) { instance_exec(*a, **b, &template) }
        else
          instance_exec(*a, **b, &template)
        end
      end.to_s
    rescue ArgumentError => e
      raise Papercraft::Error, e.message
    end
  
    # Creates a new component, applying the given parameters and or block to the
    # current one. Application is one of the principal methods of composing
    # components, particularly when passing inner components as blocks:
    #
    #   article_wrapper = H {
    #     article {
    #       emit_yield
    #     }
    #   }
    #   wrapped_article = article_wrapper.apply {
    #     h1 'Article title'
    #   }
    #   wrapped_article.render #=> "<article><h1>Article title</h1></article>"
    #
    # @param *a [<any>] normal parameters
    # @param **b [Hash] named parameters
    # @param &block [Proc] inner block
    # @return [Papercraft::Component] applied component
    def apply(*a, **b, &block)
      template = self
      if block
        Component.new(&proc do |*x, **y|
          with_block(block) { instance_exec(*a, *x, **b, **y, &template) }
        end)
      else
        Component.new(&proc do |*x, **y|
          instance_exec(*a, *x, **b, **y, &template)
        end)
      end
    end
  
    # Returns the Renderer class used for rendering the templates, according to
    # the component's mode.
    #
    # @return [Papercraft::Renderer] Renderer used for rendering the component
    def renderer_class
      case @mode
      when :html
        HTMLRenderer
      when :xml
        XMLRenderer
      else
        raise "Invalid mode #{@mode.inspect}"
      end
    end
  
    # def compile
    #   Papercraft::Compiler.new.compile(self)
    # end
  end
end
