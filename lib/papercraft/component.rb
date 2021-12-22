# frozen_string_literal: true

require_relative './html'

module Papercraft
  # Component represents a distinct, reusable HTML template. A component can
  # include other components, and also be nested inside other components.
  #
  # Since in Papercraft HTML is expressed using blocks (or procs,) the Component
  # class is simply a special kind of Proc, which has some enhanced
  # capabilities, allowing it to be easily composed in a variety of ways.

  # Components are usually created using the global methods `H` or `X`, for HTML
  # or XML templates, respectively:
  #
  #   greeter = H { |name| h1 "Hello, #{name}!" } greeter.render('world') #=>
  #   "<h1>Hello, world!</h1>"
  #
  # Components can also be created using the normal constructor:
  #
  #   greeter = Papercraft::Component.new { |name| h1 "Hello, #{name}!" }
  #   greeter.render('world') #=> "<h1>Hello, world!</h1>"
  #
  # In the component block, HTML elements are created by simply calling
  # unqualified methods:
  class Component < Proc
    # Initializes a component with the given block
    # @param mode [Symbol] local context
    # @param block [Proc] nested HTML block
    def initialize(mode: :html, &block)
      @mode = mode
      super(&block)
    end
  
    H_EMPTY = {}.freeze
  
    # Renders the associated block and returns the string result
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
  
    def apply(*a, **b, &block)
      template = self
      if block
        Component.new(&proc do |*x, **y|
          with_block(block) { instance_exec(*x, **y, &template) }
        end)
      else
        Component.new(&proc do |*x, **y|
          instance_exec(*a, **b, &template)
        end)
      end
    end
  
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
