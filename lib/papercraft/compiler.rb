# frozen_string_literal: true

require 'sirop'
require 'erb/escape'

require_relative './compiler/nodes'
require_relative './compiler/tag_translator'

module Papercraft
  # A Compiler converts a template into an optimized form that generates HTML
  # efficiently.
  class Compiler < Sirop::Sourcifier
    @@html_debug_attribute_injector = nil

    def self.html_debug_attribute_injector=(proc)
      @@html_debug_attribute_injector = proc
    end

    # Compiles the given proc, returning the generated source map and the
    # generated optimized source code.
    #
    # @param proc [Proc] template
    # @param mode [Symbol] compilation mode (:html, :xml)
    # @param wrap [bool] whether to wrap the generated code with a literal Proc definition
    # @return [Array] array containing the source map and generated code
    def self.compile_to_code(proc, mode: :html, wrap: true)
      ast = Sirop.to_ast(proc)

      # adjust ast root if proc is defined with proc {} / lambda {} syntax
      ast = ast.block if ast.is_a?(Prism::CallNode)

      compiler = new(mode:).with_source_map(proc, ast)
      transformed_ast = TagTranslator.transform(ast.body, ast)
      compiler.format_compiled_template(transformed_ast, ast, wrap:, binding: proc.binding)
      [compiler.source_map, compiler.buffer]
    end

    # Compiles the given template into an optimized Proc that generates HTML.
    #
    #     template = -> {
    #       h1 'Hello, world!'
    #     }
    #     compiled = Papercraft::Compiler.compile(template)
    #     compiled.render #=> '<h1>Hello, world!'
    #
    # @param proc [Proc] template
    # @param mode [Symbol] compilation mode (:html, :xml)
    # @param wrap [bool] whether to wrap the generated code with a literal Proc definition
    # @return [Proc] compiled proc
    def self.compile(proc, mode: :html, wrap: true)
      source_map, code = compile_to_code(proc, mode:, wrap:)
      if ENV['DEBUG'] == '1'
        puts '*' * 40
        puts code
      end
      eval(code, proc.binding, source_map[:compiled_fn])
    end

    def self.source_map_store
      @source__map_store ||= {}
    end

    def self.store_source_map(source_map)
      return if !source_map

      fn = source_map[:compiled_fn]
      source_map_store[fn] = source_map
    end

    def self.source_location_to_fn(source_location)
      "::(#{source_location.join(':')})"
    end

    attr_reader :source_map

    # Initializes a compiler.
    def initialize(mode:, **)
      super(**)
      @mode = mode
      @pending_html_parts = []
      @level = 0
    end

    # Initializes a source map.
    #
    # @param orig_proc [Proc] template proc
    # @param orig_ast [Prism::Node] template AST
    # @return [self]
    def with_source_map(orig_proc, orig_ast)
      @fn = orig_proc.source_location.first
      @orig_proc = orig_proc
      @orig_proc_fn = orig_proc.source_location.first
      @source_map = {
        source_fn: orig_proc.source_location.first,
        compiled_fn: Compiler.source_location_to_fn(orig_proc.source_location)
      }
      @source_map_line_ofs = 2
      self
    end

    def update_source_map(str = nil)
      return if !@source_map

      buffer_cur_line = @buffer.count("\n") + 1
      orig_source_cur_line = @last_loc_start ? @last_loc_start.first : '?'
      @source_map[buffer_cur_line + @source_map_line_ofs] ||=
        "#{@orig_proc_fn}:#{orig_source_cur_line}"
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
      update_source_map
      visit(ast)
      flush_html_parts!(semicolon_prefix: true)
      update_source_map

      source_code = @buffer
      @buffer = +''
      if wrap
        @source_map[2] = "#{@orig_proc_fn}:#{loc_start(orig_ast.location).first}"
        emit("# frozen_string_literal: true\n->(__buffer__")

        params = orig_ast.parameters
        params = params&.parameters
        if params
          emit(', ')
          emit(format_code(params))
        end

        if @render_yield_used || @render_children_used
          emit(', &__block__')
        end

        emit(") {\n")

      end
      @buffer << source_code
      emit_defer_postlude if @defer_mode
      if wrap
        emit('; __buffer__')
        adjust_whitespace(orig_ast.closing_loc)
        emit('}')
      end
      update_source_map
      Compiler.store_source_map(@source_map)
      @buffer
    end

    # Visits a tag node.
    #
    # @param node [Papercraft::TagNode] node
    # @return [void]
    def visit_tag_node(node)
      @level += 1
      tag = node.tag

      # adjust_whitespace(node.location)
      is_void = is_void_element?(tag)
      is_raw_inner_text = is_raw_inner_text_element?(tag)
      is_empty = !node.block && !node.inner_text

      if is_void && !is_empty
        raise Papercraft::Error, "Void element #{tag} cannot contain child nodes or inner text"
      end

      if @mode == :xml && is_empty
        emit_html(
          node.tag_location, 
          format_xml_tag_self_closing(node.tag_location, tag, node.attributes)
        )
        return
      end

      emit_html(
        node.tag_location, format_html_tag_open(node.tag_location, tag, node.attributes)
      )
      return if is_void

      case node.block
      when Prism::BlockNode
        visit(node.block.body)
      when Prism::BlockArgumentNode
        flush_html_parts!
        adjust_whitespace(node.block)
        emit("; #{format_code(node.block.expression)}.__papercraft_compiled_proc.(__buffer__)")
      end

      if node.inner_text
        if is_static_node?(node.inner_text)
          if is_raw_inner_text
            emit_html(node.location, format_literal(node.inner_text))
          else
            emit_html(node.location, ERB::Escape.html_escape(format_literal(node.inner_text)))
          end
        else
          if is_raw_inner_text
            emit_html(node.location, interpolated(format_code(node.inner_text)))
          else
            emit_html(node.location, interpolated("ERB::Escape.html_escape((#{format_code(node.inner_text)}))"))
          end
        end
      end
      emit_html(node.location, format_html_tag_close(tag))
    ensure
      @level -= 1
    end

    # Visits a const tag node.
    #
    # @param node [Papercraft::ConstTagNode] node
    # @return [void]
    def visit_const_tag_node(node)
      flush_html_parts!
      adjust_whitespace(node.location)
      emit("; ")
      if node.call_node.receiver
        emit(format_code(node.call_node.receiver))
        emit('::')
      end
      emit("#{node.call_node.name}.__papercraft_compiled_proc.(__buffer__")
      if node.call_node.arguments
        emit(', ')
        visit(node.call_node.arguments)
      end
      emit(');')
    end

    # Visits a render node.
    #
    # @param node [Papercraft::RenderNode] node
    # @return [void]
    def visit_render_node(node)
      args = node.call_node.arguments.arguments
      first_arg = args.first

      block_embed = node.block && "&(->(__buffer__) #{format_code(node.block)}.__papercraft_compiled!)"
      block_embed = ", #{block_embed}" if block_embed && node.call_node.arguments

      flush_html_parts!
      adjust_whitespace(node.location)

      if args.length == 1
        emit("; #{format_code(first_arg)}.__papercraft_compiled_proc.(__buffer__#{block_embed})")
      else
        args_code = format_code_comma_separated_nodes(args[1..])
        emit("; #{format_code(first_arg)}.__papercraft_compiled_proc.(__buffer__, #{args_code}#{block_embed})")
      end
    end

    # Visits a text node.
    #
    # @param node [Papercraft::TextNode] node
    # @return [void]
    def visit_text_node(node)
      return if !node.call_node.arguments

      args = node.call_node.arguments.arguments
      first_arg = args.first
      if args.length == 1
        if is_static_node?(first_arg)
          emit_html(node.location, ERB::Escape.html_escape(format_literal(first_arg)))
        else
          emit_html(node.location, interpolated("ERB::Escape.html_escape(#{format_code(first_arg)})"))
        end
      else
        raise "Don't know how to compile #{node}"
      end
    end

    # Visits a raw node.
    #
    # @param node [Papercraft::RawNode] node
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
    # @param node [Papercraft::DeferNode] node
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
    # @param node [Papercraft::BuiltinNode] node
    # @return [void]
    def visit_builtin_node(node)
      case node.tag
      when :tag
        args = node.call_node.arguments&.arguments
      when :html, :html5
        emit_html(node.location, '<!DOCTYPE html>')
        emit_html(node.location, format_html_tag_open(node.location, 'html', node.attributes))
        # emit_html(node.location, '<!DOCTYPE html><html>')
        visit(node.block.body) if node.block
        emit_html(node.block.closing_loc, '</html>')
      when :markdown
        args = node.call_node.arguments
        return if !args

        emit_html(node.location, interpolated("Papercraft.markdown(#{format_code(args)})"))
      end
    end

    # Visits a extension tag node.
    #
    # @param node [Papercraft::ExtensionTagNode] node
    # @return [void]
    def visit_extension_tag_node(node)
      flush_html_parts!
      adjust_whitespace(node.location)
      emit("; Papercraft::Extensions[#{node.tag.inspect}].__papercraft_compiled_proc.(__buffer__")
      if node.call_node.arguments
        emit(', ')
        visit(node.call_node.arguments)
      end
      if node.block
        block_body = format_inline_block(node.block.body)
        block_params = []

        if node.block.parameters.is_a?(Prism::ItParametersNode)
          raise Papercraft::Error, "Blocks passed to extensions cannot use it parameter"
        end

        if (params = node.block.parameters&.parameters)
          params.requireds.each do
            block_params << format_code(it) if !it.is_a?(Prism::ItParametersNode)
          end
          params.optionals.each do
            block_params << format_code(it) if !it.is_a?(Prism::ItParametersNode)
          end
          block_params << format_code(params.rest) if params.rest
          params.posts.each do
            block_params << format_code(it) if !it.is_a?(Prism::ItParametersNode)
          end
          params.keywords.each do
            block_params << format_code(it) if !it.is_a?(Prism::ItParametersNode)
          end
          block_params << format_code(params.keyword_rest) if params.keyword_rest
        end
        block_params = block_params.empty? ? '' : ", #{block_params.join(', ')}"

        emit(", &(proc { |__buffer__#{block_params}| #{block_body} }).__papercraft_compiled!")
      end
      emit(")")
    end

    # Visits a render_yield node.
    #
    # @param node [Papercraft::RenderYieldNode] node
    # @return [void]
    def visit_render_yield_node(node)
      flush_html_parts!
      adjust_whitespace(node.location)
      guard = @render_yield_used ?
        '' : "; raise(LocalJumpError, 'no block given (render_yield)') if !__block__"
      @render_yield_used = true
      emit("#{guard}; __block__.__papercraft_compiled_proc.(__buffer__")
      if node.call_node.arguments
        emit(', ')
        visit(node.call_node.arguments)
      end
      emit(")")
    end

    # Visits a render_children node.
    #
    # @param node [Papercraft::RenderChildrenNode] node
    # @return [void]
    def visit_render_children_node(node)
      flush_html_parts!
      adjust_whitespace(node.location)
      @render_children_used = true
      emit("; __block__&.__papercraft_compiled_proc&.(__buffer__")
      if node.call_node.arguments
        emit(', ')
        visit(node.call_node.arguments)
      end
      emit(")")
    end

    def visit_block_invocation_node(node)
      flush_html_parts!
      adjust_whitespace(node.location)

      emit("; #{node.call_node.receiver.name}.__papercraft_compiled_proc.(__buffer__")
      if node.call_node.arguments
        emit(', ')
        visit(node.call_node.arguments)
      end
      if node.call_node.block
        emit(", &(->")
        visit(node.call_node.block)
        emit(").__papercraft_compiled_proc")
      end
      emit(")")
    end

    private

    # Overrides the Sourcifier behaviour to flush any buffered HTML parts.
    #
    # @param loc [Prism::Location] location
    # @param semicolon [bool] prefix a semicolon before emitted code
    # @param chomp [bool] chomp the emitted code
    # @param flush_html [bool] flush pending HTML parts before emitting the code
    # @return [void]
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
      Compiler.new(mode: @mode, minimize_whitespace: true).to_source(node)
    end

    def format_inline_block(node)
      Compiler.new(mode: @mode, minimize_whitespace: true).format_compiled_template(node, node, wrap: false, binding: @binding)
    end

    # Formats a comma separated list of AST nodes. Used for formatting partial
    # argument lists.
    #
    # @param list [Array<Prism::Node>] node list
    # @return [String] generated source code
    def format_code_comma_separated_nodes(list)
      compiler = Compiler.new(mode: @mode, minimize_whitespace: true)
      compiler.visit_comma_separated_nodes(list)
      compiler.buffer
    end

    VOID_TAGS = %w(area base br col embed hr img input link meta param source track wbr)

    # Returns true if given HTML element is void (needs no closing tag).
    #
    # @param tag [String, Symbol] HTML tag
    # @return [bool] void or not
    def is_void_element?(tag)
      return false if @mode == :xml

      VOID_TAGS.include?(tag.to_s)
    end

    RAW_INNER_TEXT_TAGS = %w(style script)

    def is_raw_inner_text_element?(tag)
      return false if @mode == :xml

      RAW_INNER_TEXT_TAGS.include?(tag.to_s)
    end

    def format_xml_tag_self_closing(loc, tag, attributes)
      tag = convert_tag(tag)
      if attributes && attributes&.elements.size > 0 || @@html_debug_attribute_injector
        "<#{tag} #{format_html_attributes(loc, attributes)}/>"
      else
        "<#{tag}/>"
      end
    end

    # Formats an open tag with optional attributes.
    #
    # @param loc [Prism::Location] tag location
    # @param tag [String, Symbol] HTML tag
    # @param attributes [Hash, nil] attributes
    # @return [String] HTML
    def format_html_tag_open(loc, tag, attributes)
      tag = convert_tag(tag)
      if attributes && attributes&.elements.size > 0 || @@html_debug_attribute_injector
        "<#{tag} #{format_html_attributes(loc, attributes)}>"
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
        Papercraft.underscores_to_dashes(tag.unescaped)
      when Prism::Node
        interpolated("Papercraft.underscores_to_dashes(#{format_code(tag)})")
      else
        Papercraft.underscores_to_dashes(tag)
      end
    end

    # Formats a literal value for the given node.
    #
    # @param node [Prism::Node] AST node
    # @return [String] literal representation
    def format_literal(node)
      case node
      when Prism::SymbolNode, Prism::StringNode
        # since the value is copied verbatim into a quoted string, we need to
        # add a backslash before any double quote.
        node.unescaped.gsub('"', '\"')
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
    # @param loc [Prism::Location] tag location
    # @param node [Prism::Node] attributes node
    # @return [String] HTML
    def format_html_attributes(loc, node)
      elements = node&.elements || []
      if elements.any? { is_dynamic_attribute?(it) }
        return format_html_dynamic_attributes(loc, node)
      end

      injected_atts = format_injected_attributes(loc)
      parts = elements.map { format_attribute(it.key, it.value) }
      (injected_atts + parts).compact.join(' ')
    end

    # Formats dynamic HTML attributes from the given node.
    #
    # @param loc [Prism::Location] tag location
    # @param node [Prism::Node] attributes node
    # @return [String] HTML
    def format_html_dynamic_attributes(loc, node)
      injected_atts = compute_injected_attributes(loc)
      if injected_atts.empty?
        return interpolated("Papercraft.format_tag_attrs(#{format_code(node)})")
      else
        return interpolated("Papercraft.format_tag_attrs(#{injected_atts.inspect}.merge(#{format_code(node)}))")
      end
    end

    # Returns true if the given node is a dynamic node.
    #
    # @param node [Prism::Node] attributes node
    # @return [bool] is node dynamic
    def is_dynamic_attribute?(node)
      node.is_a?(Prism::AssocSplatNode) || !is_static_node?(node.key) || !is_static_node?(node.value)
    end

    # Computes injected attributes for the given tag location.
    #
    # @param loc [Prism::Location] tag location
    # @return [Hash] injected attributes hash
    def compute_injected_attributes(loc)
      return {} if (@mode == :xml) || !@@html_debug_attribute_injector

      loc = loc_start(loc)
      @@html_debug_attribute_injector&.(@level, @fn, loc[0], loc[1] + 1)
    end

    # Computes injected attributes for the given tag location.
    #
    # @param loc [Prism::Location] tag location
    # @return [Array<String>] array of attribute strings
    def format_injected_attributes(loc)
      atts = compute_injected_attributes(loc)
      atts.map { |k, v| format_attribute(k, v) }
    end

    # Formats a tag attribute with the given key and value. A nil, or false
    # value will return nil.
    #
    # @param key [any] attribute key
    # @param value [any] attribute value
    # @return [String, nil] formatted attribute
    def format_attribute(key, value)
      case value
      when Prism::TrueNode
        format_literal(key)
      when Prism::FalseNode, Prism::NilNode
        nil
      when String, Integer, Float, Symbol
        "#{Papercraft.underscores_to_dashes(key)}=\\\"#{value}\\\""
      else
        key = format_literal(key)
        if is_static_node?(value)
          value = format_literal(value)
          "#{Papercraft.underscores_to_dashes(key)}=\\\"#{value}\\\""
        else
          "#{Papercraft.underscores_to_dashes(key)}=\\\"#\{#{format_code(value)}}\\\""
        end
      end
    end

    # Emits HTML into the pending HTML buffer.
    #
    # @param loc [Prism::Location] location
    # @param str [String] HTML
    # @return [void]
    def emit_html(loc, str)
      @html_loc_start ||= loc
      @html_loc_end ||= loc
      @pending_html_parts << [loc, str]
    end

    # Flushes pending HTML parts to the source code buffer.
    #
    # @return [void]
    def flush_html_parts!(semicolon_prefix: true)
      return if @pending_html_parts.empty?

      adjust_whitespace(@html_loc_start, advance_to_end: false)
      emit('; __buffer__')
      concatenated = +''

      last_loc = @html_loc_start
      @pending_html_parts.each do |(loc, part)|
        if (m = part.match(/^#\{(.+)\}$/m))
          # interpolated part
          emit_html_buffer_push(concatenated, quotes: true) if !concatenated.empty?
          # adjust_whitespace(loc, advance_to_end: false)
          emit_html_buffer_push(m[1], loc:)
        else
          concatenated << part
        end
        last_loc = loc
      end
      emit_html_buffer_push(concatenated, quotes: true) if !concatenated.empty?

      @pending_html_parts.clear

      @last_loc = last_loc
      @last_loc_start = loc_start(@last_loc)
      @last_loc_end = @last_loc_start

      @html_loc_start = nil
      @html_loc_end = nil
    end

    # Emits HTML buffer push code to the given source code buffer.
    #
    # @param buf [String] source code buffer
    # @param part [String] HTML part
    # @param quotes [bool] whether to wrap emitted HTML in double quotes
    # @return [void]
    def emit_html_buffer_push(part, quotes: false, loc: nil)
      return if part.empty?

      q = quotes ? '"' : ''
      if loc
        emit(".<<(")
        adjust_whitespace(loc, advance_to_end: false)
        emit("#{q}#{part}#{q}")
        emit(")")
      else
        emit(".<<(#{q}#{part}#{q})")
      end
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
