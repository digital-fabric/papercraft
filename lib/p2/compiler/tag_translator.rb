# frozen_string_literal: true

require 'prism'
require_relative './nodes'

module P2
  # Translates a normal proc AST into an AST containing custom nodes used for
  # generating HTML. This translation is the first step in compiling templates
  # into procs that generate HTML.
  class TagTranslator < Prism::MutationCompiler
    include Prism::DSL

    def self.transform(ast)
      ast.accept(new)
    end

    def visit_call_node(node)
      # We're only interested in compiling method calls without a receiver
      return super(node) if node.receiver

      case node.name
      when :emit_yield
        yield_node(
          location: node.location,
          arguments: node.arguments
        )
      when :raise
        super(node)
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
        TagNode.new(node, self)
      end
    end
  end
end
