# frozen_string_literal: true

require 'sirop'
require 'erb/escape'

require_relative './compiler/nodes'
require_relative './compiler/tag_translator'

module P2
  # A Compiler converts a template into an optimized form that generates HTML
  # efficiently.
  class Compiler < Sirop::Sourcifier
    # Compiles the given proc, returning the generated source map and the
    # generated optimized source code.
    #
    # @param proc [Proc] template
    # @param wrap [bool] whether to wrap the generated code with a literal Proc definition
    # @return [Array] array containing the source map and generated code
    def self.compile_to_code(proc, wrap: true)
      ast = Sirop.to_ast(proc)

      # adjust ast root if proc is defined with proc {} / lambda {} syntax
      ast = ast.block if ast.is_a?(Prism::CallNode)

      compiler = new.with_source_map(proc, ast)
      transformed_ast = TagTranslator.transform(ast.body)
      compiler.format_compiled_template(transformed_ast, ast, wrap:, binding: proc.binding)
      [compiler.source_map, compiler.buffer]
    end

    # Compiles the given template into an optimized Proc that generates HTML.
    #
    #     template = -> {
    #       h1 'Hello, world!'
    #     }
    #     compiled = P2::Compiler.compile(template)
    #     compiled.render #=> '<h1>Hello, world!'
    #
    # @param proc [Proc] template
    # @param wrap [bool] whether to wrap the generated code with a literal Proc definition
    # @return [Proc] compiled proc
    def self.compile(proc, wrap: true)
      source_map, code = compile_to_code(proc, wrap:)
      if ENV['DEBUG'] == '1'
        puts '*' * 40
        puts code
      end
      eval(code, proc.binding, source_map[:compiled_fn])
    end

    attr_reader :source_map

    # Initializes a compiler.
    def initialize(**)
      super(**)
      @pending_html_parts = []
      @html_loc_start = nil
      @html_loc_end = nil
      @yield_used = nil
    end

    # Initializes a source map.
    #
    # @param orig_proc [Proc] template proc
    # @param orig_ast [Prism::Node] template AST
    # @return [self]
    def with_source_map(orig_proc, orig_ast)
      compiled_fn = "::(#{orig_proc.source_location.join(':')})"
      @source_map = {
        source_fn: orig_proc.source_location.first,
        compiled_fn: compiled_fn
      }
      @source_map_line_ofs = 2
      self
    end

    # Formats the source code for a compiled template proc.
    #
    # @param ast [Prism::Node] translated AST
    # @param orig_ast [Prism::Node] original template AST
    # @param wrap [bool] whether to wrap the generated code with a literal Proc definition
    # @return [String] compiled template source code
    def format_compiled_template(ast, orig_ast, wrap:, binding:)
      # generate source code
      @binding = binding
      visit(ast)
      flush_html_parts!(semicolon_prefix: true)
      update_source_map

      source_code = @buffer
      @buffer = +''
      if wrap
        emit("# frozen_string_literal: true\n(#{@source_map.inspect}).then { |src_map| ->(__buffer__")

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
      emit_defer_postlude if @defer_mode
      if wrap
        emit('; __buffer__')
        adjust_whitespace(orig_ast.closing_loc)
        emit(";") if @buffer !~ /\n\s*$/m
        emit("rescue Exception => e; P2.translate_backtrace(e, src_map); raise e; end }")
      end
      @buffer
    end

    # Visits a tag node.
    #
    # @param node [P2::TagNode] node
    # @return [void]
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
          emit_html(node.location, ERB::Escape.html_escape(format_literal(node.inner_text)))
        else
          convert_to_s = !is_string_type_node?(node.inner_text)
          if convert_to_s
            emit_html(node.location, interpolated("ERB::Escape.html_escape((#{format_code(node.inner_text)}).to_s)"))
          else
            emit_html(node.location, interpolated("ERB::Escape.html_escape(#{format_code(node.inner_text)})"))
          end
        end
      end
      emit_html(node.location, format_html_tag_close(tag))
    end

    # Visits a const tag node.
    #
    # @param node [P2::ConstTagNode] node
    # @return [void]
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

    # Visits a render node.
    #
    # @param node [P2::RenderNode] node
    # @return [void]
    def visit_render_node(node)
      args = node.call_node.arguments.arguments
      first_arg = args.first

      block_embed = node.block && "&(->(__buffer__) #{format_code(node.block)}.compiled!)"
      block_embed = ", #{block_embed}" if block_embed && node.call_node.arguments

      flush_html_parts!
      adjust_whitespace(node.location)

      if args.length == 1
        emit("; #{format_code(first_arg)}.compiled_proc.(__buffer__#{block_embed})")
      else
        args_code = format_code_comma_separated_nodes(args[1..])
        emit("; #{format_code(first_arg)}.compiled_proc.(__buffer__, #{args_code}#{block_embed})")
      end
    end

    # Visits a text node.
    #
    # @param node [P2::TextNode] node
    # @return [void]
    def visit_text_node(node)
      return if !node.call_node.arguments

      args = node.call_node.arguments.arguments
      first_arg = args.first
      if args.length == 1
        if is_static_node?(first_arg)
          emit_html(node.location, ERB::Escape.html_escape(format_literal(first_arg)))
        else
          emit_html(node.location, interpolated("ERB::Escape.html_escape(#{format_code(first_arg)}.to_s)"))
        end
      else
        raise "Don't know how to compile #{node}"
      end
    end

    # Visits a raw node.
    #
    # @param node [P2::RawNode] node
    # @return [void]
    def visit_raw_node(node)
      return if !node.call_node.arguments

      args = node.call_node.arguments.arguments
      first_arg = args.first
      if args.length == 1
        if is_static_node?(first_arg)
          emit_html(node.location, format_literal(first_arg))
        else
          emit_html(node.location, interpolated("(#{format_code(first_arg)}).to_s"))
        end
      else
        raise "Don't know how to compile #{node}"
      end
    end

    # Visits a defer node.
    #
    # @param node [P2::DeferNode] node
    # @return [void]
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

    # Visits a builtin node.
    #
    # @param node [P2::BuiltinNode] node
    # @return [void]
    def visit_builtin_node(node)
      case node.tag
      when :tag
        args = node.call_node.arguments&.arguments
      when :html5
        emit_html(node.location, '<!DOCTYPE html><html>')
        visit(node.block.body) if node.block
        emit_html(node.block.closing_loc, '</html>')
      when :markdown
        args = node.call_node.arguments
        return if !args

        emit_html(node.location, interpolated("P2.markdown(#{format_code(args)})"))
      end
    end

    # Visits a yield node.
    #
    # @param node [P2::YieldNode] node
    # @return [void]
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

    # Overrides the Sourcifier behaviour to flush any buffered HTML parts.
    def emit_code(loc, semicolon: false, chomp: false, flush_html: true)
      flush_html_parts! if flush_html
      super(loc, semicolon:, chomp: )
    end

    # Returns the given str inside interpolation syntax (#{...}).
    #
    # @param str [String] input string
    # @return [String] output string
    def interpolated(str)
      "#\{#{str}}"
    end

    # Formats the given AST with minimal whitespace. Used for formatting
    # arbitrary expressions.
    #
    # @param node [Prism::Node] AST
    # @return [String] generated source code
    def format_code(node)
      Compiler.new(minimize_whitespace: true).to_source(node)
    end

    # Formats a comma separated list of AST nodes. Used for formatting partial
    # argument lists.
    #
    # @param list [Array<Prism::Node>] node list
    # @return [String] generated source code
    def format_code_comma_separated_nodes(list)
      compiler = self.class.new(minimize_whitespace: true)
      compiler.visit_comma_separated_nodes(list)
      compiler.buffer
    end

    VOID_TAGS = %w(area base br col embed hr img input link meta param source track wbr)

    # Returns true if given HTML element is void (needs no closing tag).
    #
    # @param tag [String, Symbol] HTML tag
    # @return [bool] void or not
    def is_void_element?(tag)
      VOID_TAGS.include?(tag.to_s)
    end

    # Formats an open tag with optional attributes.
    #
    # @param tag [String, Symbol] HTML tag
    # @param attributes [Hash, nil] attributes
    # @return [String] HTML
    def format_html_tag_open(tag, attributes)
      tag = convert_tag(tag)
      if attributes && attributes&.elements.size > 0
        "<#{tag} #{format_html_attributes(attributes)}>"
      else
        "<#{tag}>"
      end
    end

    # Formats a close tag.
    #
    # @param tag [String, Symbol] HTML tag
    # @return [String] HTML
    def format_html_tag_close(tag)
      tag = convert_tag(tag)
      "</#{tag}>"
    end

    # Converts a tag's underscores to dashes. If tag is dynamic, emits code to
    # convert underscores to dashes at runtime.
    #
    # @param tag [any] tag
    # @return [String] convert tag or code
    def convert_tag(tag)
      case tag
      when Prism::SymbolNode, Prism::StringNode
        P2.underscores_to_dashes(tag.unescaped)
      when Prism::Node
        interpolated("P2.underscores_to_dashes(#{format_code(tag)})")
      else
        P2.underscores_to_dashes(tag)
      end
    end

    # Formats a literal value for the given node.
    #
    # @param node [Prism::Node] AST node
    # @return [String] literal representation
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
        interpolated(format_code(node))
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

    # Returns true if given node is static, i.e. is a literal value.
    #
    # @param node [Prism::Node] AST node
    # @return [bool] static or not
    def is_static_node?(node)
      STATIC_NODE_TYPES.include?(node.class)
    end

    STRING_TYPE_NODE_TYPES = [
      Prism::StringNode,
      Prism::InterpolatedStringNode
    ]

    # Returns true if given node a string or interpolated string.
    #
    # @param node [Prism::Node] AST node
    # @return [bool] string node or not
    def is_string_type_node?(node)
      STRING_TYPE_NODE_TYPES.include?(node.class)
    end

    # Formats HTML attributes from the given node.
    #
    # @param node [Prism::Node] AST node
    # @return [String] HTML
    def format_html_attributes(node)
      elements = node.elements
      dynamic_attributes = elements.any? do
        it.is_a?(Prism::AssocSplatNode) ||
          !is_static_node?(it.key) || !is_static_node?(it.value)
      end

      return interpolated("P2.format_tag_attrs(#{format_code(node)})") if dynamic_attributes

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
            "#{P2.underscores_to_dashes(k)}=\\\"#{value}\\\""
          else
            "#{P2.underscores_to_dashes(k)}=\\\"#\{#{format_code(value)}}\\\""
          end
        end
      end

      parts.compact.join(' ')
    end

    # Emits HTML into the pending HTML buffer.
    #
    # @param loc [Prism::Location] location
    # @param str [String] HTML
    # @return [void]
    def emit_html(loc, str)
      @html_loc_start ||= loc
      @html_loc_end = loc
      @pending_html_parts << str
    end

    # Flushes pending HTML parts to the source code buffer.
    #
    # @return [void]
    def flush_html_parts!(semicolon_prefix: true)
      return if @pending_html_parts.empty?

      adjust_whitespace(@html_loc_start)

      code = +''
      part = +''

      @pending_html_parts.each do
        if (m = it.match(/^#\{(.+)\}$/m))
          emit_html_buffer_push(code, part, quotes: true) if !part.empty?
          emit_html_buffer_push(code, m[1])
        else
          part << it
        end
      end
      emit_html_buffer_push(code, part, quotes: true) if !part.empty?

      @pending_html_parts.clear

      @last_loc = @html_loc_end
      @last_loc_start = loc_start(@html_loc_end)
      @last_loc_end = loc_end(@html_loc_end)

      @html_loc_start = nil
      @html_loc_end = nil

      emit code
    end

    # Emits HTML buffer push code to the given source code buffer.
    #
    # @param buf [String] source code buffer
    # @param part [String] HTML part
    # @param quotes [bool] whether to wrap emitted HTML in double quotes
    # @return [void]
    def emit_html_buffer_push(buf, part, quotes: false)
      return if part.empty?

      q = quotes ? '"' : ''
      buf << "; __buffer__ << #{q}#{part}#{q}"
      part.clear
    end

    # Emits postlude code for templates with deferred parts.
    #
    # @return [void]
    def emit_defer_postlude
      emit("; __buffer__ = __orig_buffer__; __parts__.each { it.is_a?(Proc) ? it.() : (__buffer__ << it) }")
    end
  end
end
