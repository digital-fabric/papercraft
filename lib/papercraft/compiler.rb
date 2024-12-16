# frozen_string_literal: true

require 'cgi'
require 'escape_utils'
require 'sirop'

class Papercraft::Compiler < Sirop::Sourcifier
  module AuxMethods
    def format_html_attr(tag)
      tag.to_s.tr('_', '-')
    end
  
    def format_html_attrs(attrs)
      attrs.reduce(+'') do |html, (k, v)|
        html << ' ' if !html.empty?
        html << "#{format_html_attr(k)}=\"#{v}\""
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
    embed_visit(node, '#{CGI.escapeHTML((', ').to_s)}')
  end

  def tag_attr_embed_visit(node, key)
    if key
      embed_visit(node, '#{Papercraft.format_html_attr(', ')}')
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
      value = Papercraft.format_html_attr(value) if key
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
