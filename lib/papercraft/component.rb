# frozen_string_literal: true

require_relative './html'

module Papercraft
  class Component
    attr_reader :template

    # Initializes a component with the given block
    # @param ctx [Hash] local context
    # @param block [Proc] nested HTML block
    # @param [void]
    def initialize(mode: :html, **ctx, &block)
      @mode = mode
      @template = ctx.empty? ? block : proc { with(**ctx, &block) }
    end
  
    H_EMPTY = {}.freeze
  
    # Renders the associated block and returns the string result
    # @param context [Hash] context
    # @return [String]
    def render(context = H_EMPTY, &block)
      if block
        context = context.dup if context.frozen?
        context[:__block__] = block
      end
      renderer_class.new(context, @template).to_s
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
  
    def to_proc
      @template
    end
  
    @@cache = {}
  
    def self.cache
      @@cache
    end

    def self.xml(**ctx, &block)
      new(mode: :xml, **ctx, &block)
    end
  end
end
