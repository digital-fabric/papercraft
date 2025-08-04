# frozen_string_literal: true

require 'cgi'
require 'escape_utils'
require 'sirop'

module P2
  class TagNode
    attr_reader :call_node, :location, :tag, :tag_location, :inner_text, :attributes, :block

    def initialize(call_node, compiler)
      @call_node = call_node
      @location = call_node.location
      @tag = call_node.name
      @block = call_node.block && compiler.visit(call_node.block)
      if @block
        offset = @location.start_offset
        length = call_node.block.opening_loc.start_offset - offset
        @tag_location = @location.copy(start_offset: offset, length: length)
      else
        @tag_location = @location
      end

      args = call_node.arguments&.arguments
      return if !args

      if args.size == 1 && args.first.is_a?(Prism::KeywordHashNode)
        @inner_text = nil
        @attributes = args.first
      else
        @inner_text = args.first
        @attributes = args[1].is_a?(Prism::KeywordHashNode) ? args[1] : nil
      end
    end

    def accept(visitor)
      visitor.visit_tag_node(self)
    end
  end

  class EmitNode
    attr_reader :call_node, :location, :block

    def initialize(call_node, compiler)
      @call_node = call_node
      @location = call_node.location
      @block = call_node.block && compiler.visit(call_node.block)
    end

    def accept(visitor)
      visitor.visit_emit_node(self)
    end
  end

  class TextNode
    attr_reader :call_node, :location

    def initialize(call_node, _compiler)
      @call_node = call_node
      @location = call_node.location
    end

    def accept(visitor)
      visitor.visit_text_node(self)
    end
  end

  class DeferNode
    attr_reader :call_node, :location, :block

    def initialize(call_node, compiler)
      @call_node = call_node
      @location = call_node.location
      @block = call_node.block && compiler.visit(call_node.block)
    end

    def accept(visitor)
      visitor.visit_defer_node(self)
    end
  end

  class CustomTagNode
    attr_reader :tag, :call_node, :location, :block

    def initialize(call_node, compiler)
      @call_node = call_node
      @tag = call_node.name
      @location = call_node.location
      @block = call_node.block && compiler.visit(call_node.block)
    end

    def accept(visitor)
      visitor.visit_custom_tag_node(self)
    end
  end

  class TagTransformer < Prism::MutationCompiler
    include Prism::DSL

    def self.transform(ast)
      ast.accept(new)
    end

    def visit_call_node(node)
      # We're only interested in compiling method calls without a receiver
      return super(node) if node.receiver

      case node.name
      when :emit
        EmitNode.new(node, self)
      when :text
        TextNode.new(node, self)
      when :defer
        DeferNode.new(node, self)
      when :html5, :emit_markdown
        CustomTagNode.new(node, self)
      else
        TagNode.new(node, self)
      end
    end
  end

  class VerbatimSourcifier < Sirop::Sourcifier
    def visit_tag_node(node)
      visit(node.call_node)
    end
  end

  class TemplateCompiler < Sirop::Sourcifier
    def self.compile_to_code(proc, wrap = true)
      ast = Sirop.to_ast(proc)

      transformed_ast = TagTransformer.transform(ast.body)
      new.format_compiled_template(transformed_ast, ast, wrap)
    end

    def self.compile(proc, wrap = true)
      code = compile_to_code(proc, wrap)
      eval(code, proc.binding)
    end

    def initialize(**)
      super(**)
      @pending_html_parts = []
      @html_loc_start = nil
      @html_loc_end = nil
    end

    def format_compiled_template(ast, orig_ast, wrap = true)
      if wrap
        emit('->(__buffer__')

        params = orig_ast.parameters
        params = params&.parameters
        if params
          emit(', ')
          emit(format_code(params))
        end
        
        emit(") {\n")
      end
      visit(ast)
      flush_html_parts!(semicolon_prefix: true)
      emit_postlude
      if wrap
        emit('; __buffer__')
        adjust_whitespace(orig_ast.closing_loc)
        emit('}')
      end
      @buffer
    end

    def emit_code(loc, semicolon: false, chomp: false, flush_html: true)
      flush_html_parts! if flush_html
      super(loc, semicolon:, chomp: )
    end

    def visit_tag_node(node)
      is_void = is_void_element?(node.tag)
      emit_html(node.tag_location, format_html_tag_open(node.tag, node.attributes))
      return if is_void

      visit(node.block.body) if node.block
      if node.inner_text
        if is_static_node?(node.inner_text)
          emit_html(node.location, CGI.escape_html(format_literal(node.inner_text)))
        else
          convert_to_s = !is_string_type_node?(node.inner_text)
          if convert_to_s
            emit_html(node.location, "#\{CGI.escape_html((#{format_code(node.inner_text)}).to_s)}")
          else
            emit_html(node.location, "#\{CGI.escape_html(#{format_code(node.inner_text)})}")
          end
        end
      end
      emit_html(node.location, format_html_tag_close(node.tag))
    end

    def visit_emit_node(node)
      args = node.call_node.arguments.arguments
      first_arg = args.first
      if args.length == 1
        if is_static_node?(first_arg)
          emit_html(node.location, format_literal(first_arg))
        else
          emit_html(node.location, "#\{P2.render_emit_call(#{format_code(first_arg)})}")
        end
      else
        block_embed = node.block ? " #{format_code(node.block, VerbatimSourcifier)}" : ''
        emit_html(node.location, "#\{P2.render_emit_call(#{format_code(node.call_node.arguments)})#{block_embed}}")
      end
    end

    def visit_text_node(node)
      return if !node.call_node.arguments

      args = node.call_node.arguments.arguments
      first_arg = args.first
      if args.length == 1
        if is_static_node?(first_arg)
          emit_html(node.location, CGI.escape_html(format_literal(first_arg)))
        else
          emit_html(node.location, "#\{CGI.escape_html(#{format_code(first_arg)}.to_s)}")
        end
      else
        raise "Don't know how to compile #{node}"
      end
    end

    def visit_defer_node(node)
      block = node.block
      return if !block

      flush_html_parts!

      if !@defer_mode
        adjust_whitespace(node.call_node.message_loc)
        emit("__orig_buffer__ = __buffer__; __parts__ = __buffer__ = []; ")
        @defer_mode = true
      end

      adjust_whitespace(block.opening_loc)
      emit("__buffer__ << ->{")
      visit(block.body)
      flush_html_parts!
      adjust_whitespace(block.closing_loc)
      emit("}")
    end

    def visit_custom_tag_node(node)
      case node.tag
      when :html5
        emit_html(node.location, '<!DOCTYPE html><html>')
        visit(node.block.body) if node.block
        emit_html(node.block.closing_loc, '</html>')
      when :emit_markdown
        args = node.call_node.arguments&.arguments
        md = args && args.first
        return if !md
        
        emit_html(node.location, "#\{P2.markdown(#{format_code(md)})}")
      end
    end

    private

    def format_code(node, klass = TemplateCompiler)
      klass.new(minimize_whitespace: true).to_source(node)
    end

    VOID_TAGS = %w(area base br col embed hr img input link meta param source track wbr)

    def is_void_element?(tag)
      VOID_TAGS.include?(tag.to_s)
    end

    def format_html_tag_open(tag, attributes)
      if attributes && attributes&.elements.size > 0
        "<#{tag} #{format_html_attributes(attributes)}>"
      else
        "<#{tag}>"
      end
    end

    def format_html_tag_close(tag)
      "</#{tag}>"
    end

    def format_literal(node)
      case node
      when Prism::SymbolNode, Prism::StringNode
        node.unescaped
      when Prism::IntegerNode, Prism::FloatNode
        node.value.to_s
      when Prism::InterpolatedStringNode
        format_code(node)[1..-2]
      when Prism::TrueNode
        'true'
      when Prism::FalseNode
        'false'
      when Prism::NilNode
        ''
      else
        "#\{#{format_code(node)}}"
      end
    end

    STATIC_NODE_TYPES = [
      Prism::FalseNode,
      Prism::FloatNode,
      Prism::IntegerNode,
      Prism::NilNode,
      Prism::StringNode,
      Prism::SymbolNode,
      Prism::TrueNode
    ]

    def is_static_node?(node)
      STATIC_NODE_TYPES.include?(node.class)
    end

    STRING_TYPE_NODE_TYPES = [
      Prism::StringNode,
      Prism::InterpolatedStringNode
    ]

    def is_string_type_node?(node)
      STRING_TYPE_NODE_TYPES.include?(node.class)
    end

    def format_html_attributes(node)
      elements = node.elements
      dynamic_attributes = elements.any? do
        it.is_a?(Prism::AssocSplatNode) || !is_static_node?(it.key)
      end

      return "#\{P2.format_html_attrs(#{format_code(node)})}" if dynamic_attributes

      parts = elements.map do
        key = it.key
        value = it.value
        case value
        when Prism::TrueNode
          format_literal(key)
        when Prism::FalseNode, Prism::NilNode
          nil
        else
          k = format_literal(key) 
          if is_static_node?(value)
            value = format_literal(value)
            "#{P2.format_html_attr_key(k)}=\\\"#{value}\\\""
          else
            "#{P2.format_html_attr_key(k)}=\\\"#\{#{format_code(value)}}\\\""
          end
        end
      end

      parts.compact.join(' ')
    end

    def emit_html(loc, str)
      @html_loc_start ||= loc
      @html_loc_end = loc
      @pending_html_parts << str
    end

    def flush_html_parts!(semicolon_prefix: false)
      return if @pending_html_parts.empty?

      adjust_whitespace(@html_loc_start)
      if semicolon_prefix && @buffer !~ /\n\s*$/m
        emit '; '
      end

      str = @pending_html_parts.join
      @pending_html_parts.clear

      @last_loc = @html_loc_end
      @last_loc_start = loc_start(@html_loc_end)
      @last_loc_end = loc_end(@html_loc_end)

      @html_loc_start = nil
      @html_loc_end = nil

      emit "__buffer__ << \"#{str}\""
    end

    def emit_postlude
      return if !@defer_mode

      emit("; __buffer__ = __orig_buffer__; __parts__.each { it.is_a?(Proc) ? it.() : (__buffer__ << it) }")
    end
  end

  module AuxMethods
    def format_html_attr_key(tag)
      tag.to_s.tr('_', '-')
    end
  
    def format_html_attrs(attrs)
      attrs.reduce(+'') do |html, (k, v)|
        html << ' ' if !html.empty?
        html << "#{format_html_attr_key(k)}=\"#{v}\""
      end
    end

    def render_emit_call(o, *a, **b, &block)
      case o
      when nil
        # do nothing
      when P2::Template
        o.render(*a, **b, &block)
      when ::Proc
        P2.html(&o).render(*a, **b, &block)
      else
        o.to_s
      end
    end
  end
  
  P2.extend(AuxMethods)
end
