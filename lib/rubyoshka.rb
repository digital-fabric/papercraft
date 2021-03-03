# frozen_string_literal: true

require 'escape_utils'

require_relative 'rubyoshka/renderer'

# A Rubyoshka is a template representing a piece of HTML
class Rubyoshka
  attr_reader :block

  # Initializes a Rubyoshka with the given block
  # @param ctx [Hash] local context
  # @param block [Proc] nested HTML block
  # @param [void]
  def initialize(mode: :html, **ctx, &block)
    @mode = mode
    @block = ctx.empty? ? block : proc { with(**ctx, &block) }
  end

  H_EMPTY = {}.freeze

  # Renders the associated block and returns the string result
  # @param context [Hash] context
  # @return [String]
  def render(context = H_EMPTY)
    renderer_class.new(context, &block).to_s
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

  @@cache = {}

  def self.cache
    @@cache
  end

  def self.component(&block)
    proc { |*args| new { instance_exec(*args, &block) } }
  end

  def self.xml(**ctx, &block)
    new(mode: :xml, **ctx, &block)
  end
end
::H = Rubyoshka

module ::Kernel
  # Convenience method for creating a new Rubyoshka
  # @param ctx [Hash] local context
  # @param block [Proc] nested block
  # @return [Rubyoshka] Rubyoshka template
  def H(**ctx, &block)
    Rubyoshka.new(**ctx, &block)
  end
end