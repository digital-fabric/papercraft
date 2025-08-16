# frozen_string_literal: true

require 'prism'
require_relative './nodes'

module P2
  # Translates a normal proc AST into an AST containing custom nodes used for
  # generating HTML. This translation is the first step in compiling templates
  # into procs that generate HTML.
  class TagTranslator < Prism::MutationCompiler
    include Prism::DSL

    def initialize(root)
      @root = root
      super()
    end

    def self.transform(ast, root)
      ast.accept(new(root))
    end

    def visit_call_node(node, dont_translate: false)
      return super(node) if dont_translate

      match_builtin(node) ||
      match_emit_yield(node) ||
      match_const_tag(node) ||
      match_block_call(node) ||
      # match_chained_tag(node) ||
      match_tag(node) ||
      super(node)
    end

    def match_builtin(node)
      return if node.receiver

      case node.name
      when :raise
        visit_call_node(node, dont_translate: true)
      when :render
        RenderNode.new(node, self)
      when :raw
        RawNode.new(node, self)
      when :text
        TextNode.new(node, self)
      when :defer
        DeferNode.new(node, self)
      when :html5, :markdown
        BuiltinNode.new(node, self)
      else
        nil
      end
    end

    def match_emit_yield(node)
      return if node.receiver
      return if node.name != :emit_yield

      yield_node(
        location: node.location,
        arguments: node.arguments
      )
    end

    def match_const_tag(node)
      return if node.receiver
      return if node.name !~ /^[A-Z]/

      ConstTagNode.new(node, self)
    end

    def match_block_call(node)
      return if !node.receiver
      return if node.name != :call

      receiver = node.receiver
      return if !receiver.is_a?(Prism::LocalVariableReadNode)
      return if @root.parameters&.parameters.block&.name != receiver.name

      if node.block
        raise P2::Error, 'No support for proc invocation with block'
      end

      BlockInvocationNode.new(node, self)
    end

    def match_tag(node)
      return if node.receiver

      TagNode.new(node, self)
    end
  end
end
