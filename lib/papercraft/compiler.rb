# frozen_string_literal: true

require 'cgi'
require 'escape_utils'
require 'sirop'

module Papercraft
  class TagNode
    attr_reader :location, :tag, :tag_location, :inner_text, :attributes, :block

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
      p tag: @tag, tag_location: @tag_location

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
    attr_reader :call_node, :location

    def initialize(call_node, compiler)
      @call_node = call_node
      @location = call_node.location
    end

    def accept(visitor)
      visitor.visit_emit_node(self)
    end
  end

  class TagTransformer < Prism::MutationCompiler
    include Prism::DSL

    def self.transform(ast)
      ast.accept(new)
    end

    def visit_call_node(node)
      # We're only interested in compiling method calls without a receiver
      return node if node.receiver

      case node.name
      when :emit
        EmitNode.new(node, self)
      else
        TagNode.new(node, self)
      end
    end
  end

  class TemplateCompiler < Sirop::Sourcifier
    def self.compile_to_code(obj, wrap = true)
      ast = Sirop.to_ast(obj)

      transformed_ast = TagTransformer.transform(ast.body)
      new.format_compiled_template(transformed_ast, ast, wrap)
    end

    def self.compile(obj, orig_binding = nil, wrap = true)
      code = compile_to_code(obj, wrap)
      orig_binding ? orig_binding.eval(code) : eval(code)
    end

    def initialize(**)
      super(**)
      @pending_html_parts = []
      @html_loc_start = nil
      @html_loc_end = nil
    end

    def format_compiled_template(ast, orig_ast, wrap = true)
      emit("->(__buffer__) {\n") if wrap
      visit(ast)
      flush_html_parts!
      if wrap
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
      if !is_void
        visit(node.block.body) if node.block
        emit_html(node.location, format_literal(node.inner_text)) if node.inner_text
      end
      emit_html(node.location, format_html_tag_close(node.tag)) if !is_void
    end

    def visit_emit_node(node)
      args = node.call_node.arguments.arguments
      first_arg = args.first
      p visit_emit_node: args.length, first: first_arg, a: args.length == 1, b: is_static_node?(first_arg)
      if args.length == 1 && is_static_node?(first_arg)
        emit_html(node.location, format_literal(first_arg))
      # else
      #   raise "Failed!!!!"
      end
    end

    private

    def format_code(node)
      TemplateCompiler.new(minimize_whitespace: true).to_source(node)
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

    def format_html_attributes(node)
      elements = node.elements
      dynamic_attributes = elements.any? do
        it.is_a?(Prism::AssocSplatNode) || !is_static_node?(it.key)
      end

      return "#\{Papercraft.format_html_attrs(#{format_code(node)})}" if dynamic_attributes

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
          v = format_literal(value)
          "#{Papercraft.format_html_attr_key(k)}=\\\"#{CGI.escape_html(v)}\\\""
        end
      end

      parts.compact.join(' ')
    end

    def emit_html(loc, str)
      @html_loc_start ||= loc
      @html_loc_end = loc
      @pending_html_parts << str
    end

    def flush_html_parts!
      return if @pending_html_parts.empty?

      adjust_whitespace(@html_loc_start)

      str = @pending_html_parts.join
      @pending_html_parts.clear

      @last_loc = @html_loc_end
      @last_loc_start = loc_start(@html_loc_end)
      @last_loc_end = loc_end(@html_loc_end)

      @html_loc_start = nil
      @html_loc_end = nil

      emit "__buffer__ << \"#{str}\"\n"
    end
  end
end

class Papercraft::Compiler < Sirop::Sourcifier
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
      when Papercraft::Template
        o.render(*a, **b, &block)
      when ::Proc
        Papercraft.html(&o).render(*a, **b, &block)
      else
        o.to_s
      end
    end
  end
  
  Papercraft.extend(AuxMethods)

  def initialize
    super
    @html_buffer = +''
  end

  def compile(node)
    @root_node = node
    inject_buffer_parameter(node)

    @buffer.clear
    @html_buffer.clear
    visit(node)
    @buffer
  end

  def inject_buffer_parameter(node)
    node.inject_parameters('__buffer__')
  end

  def embed_visit(node, pre = '', post = '')
    tmp_last_loc_start = @last_loc_start
    tmp_last_loc_end = @last_loc_end
    @last_loc_start = loc_start(node.location)
    @last_loc_end = loc_end(node.location)

    @embed_mode = true
    tmp_buffer = @buffer
    @buffer = +''
    visit(node)
    @embed_mode = false
    @html_buffer << "#{pre}#{@buffer}#{post}"
    @buffer = tmp_buffer

    @last_loc_start = tmp_last_loc_start
    @last_loc_end = tmp_last_loc_end
  end

  def html_embed_visit(node)
    embed_visit(node, '#{CGI.escape_html((', ').to_s)}')
  end

  def tag_attr_embed_visit(node, key)
    if key
      embed_visit(node, '#{Papercraft.format_html_attr_key(', ')}')
    else
      embed_visit(node, '#{', '}')
    end
  end

  def emit_code(loc, semicolon: false)
    flush_html_buffer if !@embed_mode
    super
  end

  def emit_html(str)
    @html_buffer << str
  end

  def flush_html_buffer
    return if @html_buffer.empty?

    if @last_loc_start
      adjust_whitespace(@html_location_start) if @html_location_start
    end
    if @defer_proc_mode
      @buffer << "__b__ << \"#{@html_buffer}\""
    elsif @defer_mode
      @buffer << "__parts__ << \"#{@html_buffer}\""
    else
      @buffer << "__buffer__ << \"#{@html_buffer}\""
    end
    @html_buffer.clear
    @last_loc_end = loc_end(@html_location_end) if @html_location_end

    @html_location_start = nil
    @html_location_end = nil
  end

  def visit_call_node(node)
    return super if node.receiver || @embed_mode

    @html_location_start ||= node.location

    case node.name
    when :text
      emit_html_text(node)
    when :emit
      emit_html_emit(node)
    when :emit_yield
      raise NotImplementedError, "emit_yield is not yet supported in compiled templates"
    when :defer
      emit_html_deferred(node)
    else
      emit_html_tag(node)
    end

    @html_location_end = node.location
  end

  def tag_args(node)
    args = node.arguments&.arguments
    return nil if !args

    if args[0]&.is_a?(Prism::KeywordHashNode)
      [nil, args[0]]
    elsif args[1]&.is_a?(Prism::KeywordHashNode)
      args
    else
      [args && args[0], nil]
    end
  end

  def emit_tag_open(node, attrs)
    emit_html("<#{node.name}")
    emit_tag_attributes(node, attrs) if attrs
    emit_html(">")
  end

  def emit_tag_close(node)
    emit_html("</#{node.name}>")
  end

  def emit_tag_open_close(node, attrs)
    emit_html("<#{node.name}")
    emit_tag_attributes(node, attrs) if attrs
    emit_html("/>")
  end

  def emit_tag_inner_text(node)
    case node
    when Prism::StringNode, Prism::SymbolNode
      @html_buffer << CGI.escapeHTML(node.unescaped)
    else
      html_embed_visit(node)
    end
  end

  def emit_tag_attributes(node, attrs)
    attrs.elements.each do |e|
      emit_html(" ")

      if e.is_a?(Prism::AssocSplatNode)
        embed_visit(e.value, '#{Papercraft.format_html_attrs(', ')}')
      else
        emit_tag_attribute_node(e.key, true)
        emit_html('=\"')
        emit_tag_attribute_node(e.value)
        emit_html('\"')
      end  
    end
  end

  def emit_tag_attribute_node(node, key = false)
    case node
    when Prism::StringNode, Prism::SymbolNode
      value = node.unescaped
      value = Papercraft.format_html_attr_key(value) if key
      @html_buffer << value
    else
      tag_attr_embed_visit(node, key)
    end
  end

  def emit_html_tag(node)
    inner_text, attrs = tag_args(node)
    block = node.block

    if inner_text
      emit_tag_open(node, attrs)
      emit_tag_inner_text(inner_text)
      emit_tag_close(node)
    elsif block
      emit_tag_open(node, attrs)
      visit(block.body)
      @html_location_start ||= node.block.closing_loc
      emit_tag_close(node)
    else
      emit_tag_open_close(node, attrs)
    end
  end

  def emit_html_text(node)
    args = node.arguments&.arguments
    return nil if !args

    emit_tag_inner_text(args[0])
  end

  def emit_html_emit(node)
    args = node.arguments&.arguments
    return nil if !args

    embed_visit(node.arguments, '#{Papercraft.render_emit_call(', ')}')
  end

  def emit_html_deferred(node)
    raise NotImplementedError, "#defer in embed mode is not supported in compiled templates" if @embed_mode

    block = node.block
    return if not block

    setup_defer_mode if !@defer_mode

    flush_html_buffer
    @buffer << ';__parts__ << ->(__b__) '
    @defer_proc_mode = true
    visit(node.block)
    @defer_proc_mode = nil
  end

  DEFER_PREFIX_EMPTY = "; __parts__ = []"
  DEFER_PREFIX_NOT_EMPTY = "; __parts__ = [__buffer__.dup]; __buffer__.clear"
  DEFER_POSTFIX = ";__parts__.each { |p| p.is_a?(Proc) ? p.(__buffer__) : (__buffer__ << p) }"

  def setup_defer_mode
    @defer_mode = true
    if @html_buffer && !@html_buffer.empty?
      @buffer << DEFER_PREFIX_NOT_EMPTY
    else
      @buffer << DEFER_PREFIX_EMPTY
    end

    @root_node.after_body do
      flush_html_buffer
      @buffer << DEFER_POSTFIX
    end
  end
end
