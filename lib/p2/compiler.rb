# frozen_string_literal: true

require 'cgi'
require 'sirop'
require 'securerandom'

module P2
  class TagNode
    attr_reader :call_node, :location, :tag, :tag_location, :inner_text, :attributes, :block

    def initialize(call_node, transformer)
      @call_node = call_node
      @location = call_node.location
      @tag = call_node.name
      prepare_block(transformer)

      args = call_node.arguments&.arguments
      return if !args

      if @tag == :tag
        @tag = args[0]
        args = args[1..]
      end

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

    def prepare_block(transformer)
      @block = call_node.block
      if @block.is_a?(Prism::BlockNode)
        @block = transformer.visit(@block)
        offset = @location.start_offset
        length = @block.opening_loc.start_offset - offset
        @tag_location = @location.copy(start_offset: offset, length: length)
      else
        @tag_location = @location
      end
    end
  end

  class EmitNode
    attr_reader :call_node, :location, :block

    include Prism::DSL

    def initialize(call_node, transformer)
      @call_node = call_node
      @location = call_node.location
      @transformer = transformer
      @block = call_node.block && transformer.visit(call_node.block)

      lambda = call_node.arguments && call_node.arguments.arguments[0]
      return unless lambda.is_a?(Prism::LambdaNode)

      location = lambda.location
      parameters = lambda.parameters
      parameters_location = parameters&.location || location
      params = parameters&.parameters
      lambda = lambda_node(
        location: location,
        parameters: block_parameters_node(
          location: parameters_location,
          parameters: parameters_node(
            location: parameters_location,
            requireds: [
              required_parameter_node(
                location: ad_hoc_string_location('__buffer__'),
                name: :__buffer__
              ),
              *params&.requireds
            ],
            optionals: transform_array(params&.optionals),
            rest: transform(params&.rest),
            posts: transform_array(params&.posts),
            keywords: transform_array(params&.keywords),
            keyword_rest: transform(params&.keyword_rest),
            block: transform(params&.block)
          )
        ),
        body: transformer.visit(lambda.body)
      )
      call_node.arguments.arguments[0] = lambda
      # pp lambda_body: call_node.arguments.arguments[0]
    end

    def ad_hoc_string_location(str)
      src = source(str)
      Prism::DSL.location(source: src, start_offset: 0, length: str.bytesize)
    end

    def transform(node)
      node && @transformer.visit(node)
    end

    def transform_array(array)
      array ? array.map { @transformer.visit(it) } : []
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
      when :emit_yield
        yield_node(
          location: node.location,
          arguments: node.arguments
        )
      when :raise
        super(node)
      when :emit, :e
        EmitNode.new(node, self)
      when :text
        TextNode.new(node, self)
      when :defer
        DeferNode.new(node, self)
      when :html5, :emit_markdown, :markdown
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
    def self.compile_to_code(proc, wrap: true)
      ast = Sirop.to_ast(proc)

      # adjust ast root if proc is defined with proc {} / lambda {} syntax
      ast = ast.block if ast.is_a?(Prism::CallNode)

      transformed_ast = TagTransformer.transform(ast.body)
      compiler = new.with_source_map(proc)
      compiler.format_compiled_template(transformed_ast, ast, wrap:, binding: proc.binding)
      [compiler.source_map, compiler.buffer].tap do |(src_map, code)|
        if ENV['DEBUG'] == '1'
          puts '*' * 40
          puts code
        end
      end
    end

    def self.compile(proc, wrap: true)
      source_map, code = compile_to_code(proc, wrap:)
      eval(code, proc.binding, source_map[:compiled_fn])
    end

    attr_reader :source_map

    def initialize(**)
      super(**)
      @pending_html_parts = []
      @html_loc_start = nil
      @html_loc_end = nil
      @yield_used = nil
    end

    def with_source_map(orig_proc)
      @source_map = {
        source_fn: orig_proc.source_location.first,
        compiled_fn: "::#{SecureRandom.alphanumeric(8)}"
      }
      @source_map_line_ofs = 1
      self
    end

    def format_compiled_template(ast, orig_ast, wrap:, binding:)
      # generate source code
      @binding = binding
      visit(ast)
      flush_html_parts!(semicolon_prefix: true)

      source_code = @buffer
      @buffer = +''
      if wrap
        emit("(#{@source_map.inspect}).then { |src_map| ->(__buffer__")

        params = orig_ast.parameters
        params = params&.parameters
        if params
          emit(', ')
          emit(format_code(params))
        end

        if @yield_used
          emit(', &__block__')
        end
        
        emit(") do\n")
      end
      @buffer << source_code
      emit_postlude
      if wrap
        emit('; __buffer__')
        adjust_whitespace(orig_ast.closing_loc)
        emit(";") if @buffer !~ /\n\s*$/m
        emit("rescue Exception => e; P2.translate_backtrace(e, src_map); raise e; end }")
      end
      @buffer
    end

    def emit_code(loc, semicolon: false, chomp: false, flush_html: true)
      flush_html_parts! if flush_html
      super(loc, semicolon:, chomp: )
    end

    def visit_tag_node(node)
      tag = node.tag
      if tag.is_a?(Symbol) && tag =~ /^[A-Z]/
        return visit_const_tag_node(node.call_node)
      end

      is_void = is_void_element?(tag)
      emit_html(node.tag_location, format_html_tag_open(tag, node.attributes))
      return if is_void

      case node.block
      when Prism::BlockNode
        visit(node.block.body)
      when Prism::BlockArgumentNode
        flush_html_parts!
        adjust_whitespace(node.block)
        emit("; #{format_code(node.block.expression)}.render_to_buffer(__buffer__)")
      end

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
      emit_html(node.location, format_html_tag_close(tag))
    end

    def visit_const_tag_node(node)
      flush_html_parts!
      adjust_whitespace(node.location)
      if node.receiver
        emit(node.receiver.location)
        emit('::')
      end
      emit("; #{node.name}.render_to_buffer(__buffer__")
      if node.arguments
        emit(', ')
        visit(node.arguments)
      end
      emit(');')
    end

    def visit_emit_node(node)
      args = node.call_node.arguments.arguments
      first_arg = args.first
      if args.length == 1
        if is_static_node?(first_arg)
          emit_html(node.location, format_literal(first_arg))
        elsif first_arg.is_a?(Prism::LambdaNode)
          visit(first_arg.body)
        else
          emit_html(node.location, "#\{P2.render_emit_call(#{format_code(first_arg)})}")
        end
      else
        block_embed = node.block ? "&(->(__buffer__) #{format_code(node.block)}.compiled!)" : nil
        block_embed = ", #{block_embed}" if block_embed && node.call_node.arguments
        emit_html(node.location, "#\{P2.render_emit_call(#{format_code(node.call_node.arguments)}#{block_embed})}")
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
      when :tag
        args = node.call_node.arguments&.arguments        
      when :html5
        emit_html(node.location, '<!DOCTYPE html><html>')
        visit(node.block.body) if node.block
        emit_html(node.block.closing_loc, '</html>')
      when :emit_markdown, :markdown
        args = node.call_node.arguments
        return if !args

        emit_html(node.location, "#\{P2.markdown(#{format_code(args)})}")
      end
    end

    def visit_yield_node(node)
      adjust_whitespace(node.location)
      flush_html_parts!
      @yield_used = true
      emit("; (__block__ ? __block__.render_to_buffer(__buffer__")
      if node.arguments
        emit(', ')
        visit(node.arguments)
      end
      emit(") : raise(LocalJumpError, 'no block given (yield)'))")
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
      tag = convert_tag(tag)
      if attributes && attributes&.elements.size > 0
        "<#{tag} #{format_html_attributes(attributes)}>"
      else
        "<#{tag}>"
      end
    end

    def format_html_tag_close(tag)
      tag = convert_tag(tag)
      "</#{tag}>"
    end

    def convert_tag(tag)
      case tag
      when Prism::SymbolNode, Prism::StringNode
        P2.format_tag(tag.unescaped)
      when Prism::Node
        "#\{P2.format_tag(#{format_code(tag)})}"
      else
        P2.format_tag(tag)
      end
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
        it.is_a?(Prism::AssocSplatNode) ||
          !is_static_node?(it.key) || !is_static_node?(it.value)
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

    def flush_html_parts!(semicolon_prefix: true)
      return if @pending_html_parts.empty?

      adjust_whitespace(@html_loc_start)
      if semicolon_prefix && @buffer =~ /[^\s]\s*$/m
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
    def format_tag(tag)
      tag.to_s.gsub('_', '-')
    end

    def format_html_attr_key(tag)
      tag.to_s.tr('_', '-')
    end
  
    def format_html_attrs(attrs)
      attrs.each_with_object(+'') do |(k, v), html|
        case v
        when nil, false
        when true
          html << ' ' if !html.empty?
          html << format_html_attr_key(k)
        else
          html << ' ' if !html.empty?
          v = v.join(' ') if v.is_a?(Array)
          html << "#{format_html_attr_key(k)}=\"#{v}\""
        end
      end
    end

    def render_emit_call(o, *a, **b, &block)
      case o
      when nil
        # do nothing
      when ::Proc
        o.render(*a, **b, &block)
      else
        o.to_s
      end
    end

    def translate_backtrace(e, source_map)
      re = /^(#{source_map[:compiled_fn]}\:(\d+))/
      source_fn = source_map[:source_fn]
      backtrace = e.backtrace.map {
        if (m = it.match(re))
          line = m[2].to_i
          source_line = source_map[line] || "?(#{line})"
          it.sub(m[1], "#{source_fn}:#{source_line}")
        else
          it
        end
      }
      e.set_backtrace(backtrace)
    end
  end
  
  P2.extend(AuxMethods)
end
