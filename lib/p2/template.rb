# frozen_string_literal: true

require_relative './html'

module P2

  # Template represents a distinct, reusable HTML template. A template can
  # include other templates, and also be nested inside other templates.
  #
  # Since in P2 HTML is expressed using blocks (or procs,) the Template
  # class is simply a special kind of Proc, which has some enhanced
  # capabilities, allowing it to be easily composed in a variety of ways.
  #
  # Templates are usually created using the class methods `html`, `xml` or
  # `json`, for HTML, XML or JSON templates, respectively:
  #
  #   greeter = P2.html { |name| h1 "Hello, #{name}!" }
  #   greeter.render('world') #=> "<h1>Hello, world!</h1>"
  #
  # Templates can also be created using the normal constructor:
  #
  #   greeter = P2::Template.new(mode: :html) { |name| h1 "Hello, #{name}!" }
  #   greeter.render('world') #=> "<h1>Hello, world!</h1>"
  #
  # The different methods for creating templates can also take a custom MIME
  # type, by passing a `mime_type` named argument:
  #
  #   json = P2.json(mime_type: 'application/feed+json') { ... }
  #
  # In the template block, HTML elements are created by simply calling
  # unqualified methods:
  #
  #   page_layout = P2.html {
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
  # P2 templates can take explicit parameters in order to render
  # dynamic content. This can be in the form of regular or named parameters. The
  # `greeter` template shown above takes a single `name` parameter. Here's how a
  # anchor template could be implemented with named parameters:
  #
  #   anchor = P2.html { |uri: , text: | a(text, href: uri) }
  #
  # The above template could later be rendered by passing the needed arguments:
  #
  #   anchor.render(uri: 'https://example.com', text: 'Example')
  #
  # ## Template Composition
  #
  # A template can be included in another template using the `emit` method:
  #
  #   links = P2.html {
  #     emit anchor, uri: '/posts',   text: 'Posts'
  #     emit anchor, uri: '/archive', text: 'Archive'
  #     emit anchor, uri: '/about',   text: 'About'
  #   }
  #
  # Another way of composing templates is to pass the templates themselves as
  # parameters:
  #
  #   links = P2.html { |anchors|
  #     anchors.each { |a| emit a }
  #   }
  #   links.render([
  #     anchor.apply(uri: '/posts', text: 'Posts'),
  #     anchor.apply(uri: '/archive', text: 'Archive'),
  #     anchor.apply(uri: '/about', text: 'About')
  #   ])
  #
  # The `#apply` method creates a new template, applying the given parameters
  # such that the template can be rendered without parameters:
  #
  #   links_with_anchors = links.apply([
  #     anchor.apply(uri: '/posts', text: 'Posts'),
  #     anchor.apply(uri: '/archive', text: 'Archive'),
  #     anchor.apply(uri: '/about', text: 'About')
  #   ])
  #   links_with_anchors.render
  #
  class Template < Proc

    # Determines the rendering mode: `:html` or `:xml`.
    attr_accessor :mode
    attr_reader :block

    # Initializes a template with the given block. The rendering mode (HTML or
    # XML) can be passed in the `mode:` parameter. If `mode:` is not specified,
    # the template defaults to HTML.
    #
    # @param mode [:html, :xml] rendering mode
    # @param mime_type [String, nil] the template's mime type (nil for default)
    # @param block [Proc] nested HTML block
    def initialize(mode: :html, &block)
      @mode = mode
      @block = block
      super(&block)
    end

    H_EMPTY = {}.freeze

    # Renders the template with the given parameters and or block, and returns
    # the string result.
    #
    # @param *params [any] unnamed parameters
    # @param **named_params [any] named parameters
    # @return [String] rendered string
    def render(*a, **b, &block)
      template = self
      Renderer.verify_proc_parameters(template, a, b)
      renderer_class.new do
        push_emit_yield_block(block) if block
        instance_exec(*a, **b, &template)
      end.to_s
    end

    # Creates a new template, applying the given parameters and or block to the
    # current one. Application is one of the principal methods of composing
    # templates, particularly when passing inner templates as blocks:
    #
    #   article_wrapper = P2.html {
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
    # @return [P2::Template] applied template
    def apply(*a, **b, &block)
      template = self
      Template.new(mode: @mode, &proc do |*x, **y|
        push_emit_yield_block(block) if block
        instance_exec(*a, *x, **b, **y, &template)
      end)
    end

    # Returns the Renderer class used for rendering the templates, according to
    # the template's mode.
    #
    # @return [P2::Renderer] Renderer used for rendering the template
    def renderer_class
      case @mode
      when :html
        HTMLRenderer
      else
        raise "Invalid mode #{@mode.inspect}"
      end
    end

    def compile(*args)
      compiled_template = P2::TemplateCompiler.compile(proc)
      ->(*a, **b) {
        buffer = +''
        compiled_template.(buffer)
        buffer
      }
    end
  end
end
