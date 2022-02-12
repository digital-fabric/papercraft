# frozen_string_literal: true

require_relative './html'
require_relative './xml'
require_relative './json'
require_relative './extension_proxy'

module Papercraft
  
  # A Renderer renders a Papercraft template into a string
  class Renderer

    class << self

      # Verifies that the given template proc can be called with the given
      # arguments and named arguments. If the proc demands named argument keys
      # that do not exist in `named_args`, `Papercraft::Error` is raised.
      #
      # @param template [Proc] proc to verify
      # @param args [Array<any>] arguments passed to proc
      # @param named_args [Hash] named arguments passed to proc
      def verify_proc_parameters(template, args, named_args)
        param_count = 0
        template.parameters.each do |(type, name)|
          case type
          when :req
            param_count += 1
          when :keyreq
            if !named_args.has_key?(name)
              raise Papercraft::Error, "Missing template parameter #{name.inspect}"
            end
          end
        end
        if param_count > args.size
          raise Papercraft::Error, "Missing template parameters"
        end
      end

      # call_seq:
      #   Papercraft::Renderer.extension(name => mod, ...)
      #   Papercraft.extension(name => mod, ...)
      #
      # Installs the given extensions, passed in the form of a Ruby hash mapping
      # methods to extension modules. The methods will be available to all
      # Papercraft templates. Extension methods are executed in the context of
      # the the renderer instance, so they can look just like normal proc
      # components. In cases where method names in the module clash with XML
      # tag names, you can use the `#tag` method to emit the relevant tag.
      # 
      # module ComponentLibrary
      #   def card(title, content)
      #     div(class: 'card') {
      #       h3 title
      #       div(class: 'card-content') { emit_markdown content }
      #     }
      #   end
      # end
      #
      # Papercraft.extension(components: ComponentLibrary)
      # Papercraft.html { components.card('Foo', '**Bar**') }
      #
      # @param map [Hash] hash mapping methods to extension modules
      # @return [void]
      def extension(map)
        map.each do |sym, mod|
          define_extension_method(sym, mod)
        end
      end

      private

      # Defines a method returning an extension proxy for the given module
      # @param sym [Symbol] method name
      # @param mod [Module] extension module
      # @return [void]
      def define_extension_method(sym, mod)
        define_method(sym) do
          (@extension_proxies ||= {})[mod] ||= ExtensionProxy.new(self, mod)
        end
      end
    end

    INITIAL_BUFFER_CAPACITY = 8192

    # Initializes the renderer and evaulates the given template in the
    # renderer's scope.
    #
    # @param &template [Proc] template block
    def initialize(&template)
      @buffer = String.new(capacity: INITIAL_BUFFER_CAPACITY)
      instance_eval(&template)
    end

    # Returns the rendered template.
    #
    # @return [String]
    def to_s
      if @parts
        last = @buffer
        @buffer = String.new(capacity: INITIAL_BUFFER_CAPACITY)
        parts = @parts
        @parts = nil
        parts.each do |p|
          if Proc === p
            render_deferred_proc(&p)
          else
            @buffer << p
          end
        end
        @buffer << last unless last.empty?
      end
      @buffer
    end

    # Emits the given object into the rendering buffer. If the given object is a
    # proc or a component, `emit` will passes any additional arguments and named
    # arguments to the object when rendering it. If the given object is nil,
    # nothing is emitted. Otherwise, the object is converted into a string using
    # `#to_s` which is then added to the rendering buffer, without any escaping.
    #
    #   greeter = proc { |name| h1 "Hello, #{name}!" }
    #   Papercraft.html { emit(greeter, 'world') }.render #=> "<h1>Hello, world!</h1>"
    #   
    #   Papercraft.html { emit 'hi&<bye>' }.render #=> "hi&<bye>"
    #   
    #   Papercraft.html { emit nil }.render #=> ""
    #
    # @param o [Proc, Papercraft::Template, String] emitted object
    # @param *a [Array<any>] arguments to pass to a proc
    # @param **b [Hash] named arguments to pass to a proc
    # @return [void]
    def emit(o, *a, **b, &block)
      case o
      when ::Proc
        Renderer.verify_proc_parameters(o, a, b)
        push_emit_yield_block(block) if block
        instance_exec(*a, **b, &o)
      when nil
      else
        @buffer << o.to_s
      end
    end
    alias_method :e, :emit

    # Emits a block supplied using `Component#apply` or `Component#render`.
    #
    #   div_wrap = Papercraft.html { |*args| div { emit_yield(*args) } }
    #   greeter = div_wrap.apply { |name| h1 "Hello, #{name}!" }
    #   greeter.render('world') #=> "<div><h1>Hello, world!</h1></div>"
    #
    # @param *a [Array<any>] arguments to pass to a proc
    # @param **b [Hash] named arguments to pass to a proc
    # @return [void]
    def emit_yield(*a, **b)
      block = @emit_yield_stack&.pop
      raise Papercraft::Error, "No block given" unless block
      
      instance_exec(*a, **b, &block)
    end

    # Defers the given block to be evaluated later. Deferred evaluation allows
    # Papercraft templates to inject state into sibling components, regardless
    # of the component's order in the container component. For example, a nested
    # component may set an instance variable used by another component. This is
    # an elegant solution to the problem of setting the XML page's title, or
    # adding elements to the `<head>` section. Here's how a title can be
    # controlled from a nested component:
    #
    #   layout = Papercraft.html {
    #     html {
    #       head {
    #         defer { title @title }
    #       }
    #       body {
    #         emit_yield
    #       }
    #     }
    #   }
    #
    #   html.render {
    #     @title = 'My super page'
    #     h1 'content'
    #   }
    #
    # @param &block [Proc] Deferred block to be emitted
    # @return [void]
    def defer(&block)
      if !@parts
        @parts = [@buffer, block]
      else
        @parts << @buffer unless @buffer.empty?
        @parts << block
      end
      @buffer = String.new(capacity: INITIAL_BUFFER_CAPACITY)
    end
    
    private

    # Escapes text. This method must be overriden in descendant classes.
    #
    # @param text [String] text to be escaped
    def escape_text(text)
      raise NotImplementedError
    end

    # Pushes the given block onto the emit_yield stack.
    #
    # @param block [Proc] block
    def push_emit_yield_block(block)
      (@emit_yield_stack ||= []) << block
    end

    # Renders a deferred proc by evaluating it, then adding the rendered result
    # to the buffer.
    #
    # @param &block [Proc] deferred proc
    # @return [void]
    def render_deferred_proc(&block)
      old_buffer = @buffer
      
      @buffer = String.new(capacity: INITIAL_BUFFER_CAPACITY)
      @parts = nil

      instance_eval(&block)

      old_buffer << to_s
      @buffer = old_buffer
    end
  end

  # Implements an HTML renderer
  class HTMLRenderer < Renderer
    include HTML
  end

  # Implements an XML renderer
  class XMLRenderer < Renderer
    include XML
  end

  class JSONRenderer < Renderer
    include JSON
  end
end
