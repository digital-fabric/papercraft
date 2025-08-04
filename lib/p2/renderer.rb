# frozen_string_literal: true

require_relative './html'

module P2

  # A Renderer renders a P2 template into a string
  class Renderer

    class << self

      # Verifies that the given template proc can be called with the given
      # arguments and named arguments. If the proc demands named argument keys
      # that do not exist in `named_args`, `P2::Error` is raised.
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
              raise P2::Error, "Missing template parameter #{name.inspect}"
            end
          end
        end
        if param_count > args.size
          raise P2::Error, "Missing template parameters"
        end
      end
    end

    # Initializes the renderer and evaulates the given template in the
    # renderer's scope.
    #
    # @param &template [Proc] template block
    def initialize(&template)
      instance_eval(&template)
    end

    # Emits the given object into the rendering buffer. If the given object is a
    # proc or a component, `emit` will passes any additional arguments and named
    # arguments to the object when rendering it. If the given object is nil,
    # nothing is emitted. Otherwise, the object is converted into a string using
    # `#to_s` which is then added to the rendering buffer, without any escaping.
    #
    #   greeter = proc { |name| h1 "Hello, #{name}!" }
    #   P2.html { emit(greeter, 'world') }.render #=> "<h1>Hello, world!</h1>"
    #
    #   P2.html { emit 'hi&<bye>' }.render #=> "hi&<bye>"
    #
    #   P2.html { emit nil }.render #=> ""
    #
    # @param o [Proc, P2::Template, String] emitted object
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
        # do nothing
      else
        emit_object(o)
      end
    end
    alias_method :e, :emit

    # Emits a block supplied using {Template#apply} or {Template#render}.
    #
    #   div_wrap = P2.html { |*args| div { emit_yield(*args) } }
    #   greeter = div_wrap.apply { |name| h1 "Hello, #{name}!" }
    #   greeter.render('world') #=> "<div><h1>Hello, world!</h1></div>"
    #
    # @param *a [Array<any>] arguments to pass to a proc
    # @param **b [Hash] named arguments to pass to a proc
    # @return [void]
    def emit_yield(*a, **b)
      block = @emit_yield_stack&.pop
      raise P2::Error, "No block given" unless block

      instance_exec(*a, **b, &block)
    end

    private

    # Pushes the given block onto the emit_yield stack.
    #
    # @param block [Proc] block
    def push_emit_yield_block(block)
      (@emit_yield_stack ||= []) << block
    end
  end

  # Implements an HTML renderer
  class HTMLRenderer < Renderer
    include HTML
  end
end
