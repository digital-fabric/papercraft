# frozen_string_literal: true

require 'cgi'
require 'escape_utils'
require 'sirop'

class Papercraft::Compiler < Sirop::Sourcifier
  def initialize
    super
    @html_buffer = +''
  end

  def compile(node)
    inject_buffer_parameter(node)

    @buffer.clear
    @html_buffer.clear
    visit(node)
    @buffer
  end

  def inject_buffer_parameter(node)
    node.inject_parameters('__buffer__')
  end

  def emit(str)
    if @embed_mode
      @embed_buffer << str
    else
      @buffer << str
    end
  end

  def embed_visit(node, pre = '', post = '')
    @embed_mode = true
    @embed_buffer = +''
    visit(node)
    @embed_mode = false
    @html_buffer << "#{pre}#{@embed_buffer}#{post}"
  end

  def html_embed_visit(node)
    embed_visit(node, '#{CGI.escapeHTML(', ')}')
  end

  def tag_attr_embed_visit(node)
    embed_visit(node, '#{', '}')
  end

  def adjust_whitespace(loc)
    super(loc) if !@embed_mode
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
    @buffer << "__buffer__ << \"#{@html_buffer}\""
    @html_buffer.clear
    @last_loc_end = loc_end(@html_location_end) if @html_location_end

    @html_location_start = nil
    @html_location_end = nil
  end

  def visit_call_node(node)
    return super if node.receiver

    @html_location_start ||= node.location
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
      emit_tag_attribute_node(e.key)
      emit_html('=\"')
      emit_tag_attribute_node(e.value)
      emit_html('\"')
    end
  end

  def emit_tag_attribute_node(node)
    case node
    when Prism::StringNode, Prism::SymbolNode
      @html_buffer << node.unescaped
    else
      tag_attr_embed_visit(node)
    end
  end
end
