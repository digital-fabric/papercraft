# frozen_string_literal: true

require 'cgi'
require 'escape_utils'

module Papercraft
  # The Compiler class compiles Papercraft templates
  class Compiler
    DEFAULT_CODE_BUFFER_CAPACITY = 8192
    DEFAULT_EMIT_BUFFER_CAPACITY = 4096

    def initialize
      @level = 0
      @code_buffer = String.new(capacity: DEFAULT_CODE_BUFFER_CAPACITY)
      @sub_templates = []
    end

    def emit_output
      @output_mode = true
      yield
      @output_mode = false
    end

    def emit_code_line_break
      return if @code_buffer.empty?

      @code_buffer << "\n" if @code_buffer[-1] != "\n"
      @line_break = nil
    end

    def emit_buffer
      @emit_buffer ||= String.new(capacity: DEFAULT_EMIT_BUFFER_CAPACITY)
    end

    def emit_literal(lit)
      if @output_mode
        emit_code_line_break if @line_break
        emit_buffer << lit
      else
        emit_code(lit)
      end
    end

    def emit_text(str, encoding: :html)
      emit_code_line_break if @line_break
      emit_buffer << encode(str, encoding).inspect[1..-2]
    end

    def emit_text_fcall(node)
      case node.type
      when :STR, :LIT, :SYM
        value = node.children.first.to_s
        emit_text(value, encoding: :html)
      when :VCALL
        emit_code("__buf__ << CGI.escapeHTML((#{node.children.first}).to_s)\n")
      when :CONST
        name = node.children.first.to_s
        value = get_const(name)
        emit_text(value, encoding: :html)
      else
        raise NotImplementedError
      end
    end

    def get_const(name)
      if @block.binding.eval("singleton_class.const_defined?(#{name.inspect})")
        @block.binding.eval("singleton_class.const_get(#{name.inspect})")
      elsif Papercraft.const_defined?(name)
        Papercraft.const_get(name)
      else
        raise NameError, "Constant #{name} not found"
      end
    end

    def encode(str, encoding)
      case encoding
      when :html
        __html_encode__(str)
      when :uri
        __uri_encode__(str)
      else
        raise "Invalid encoding #{encoding.inspect}"
      end
    end

    def __html_encode__(str)
      CGI.escapeHTML(str)
    end

    def __uri_encode__(str)
      EscapeUtils.escape_uri(str)
    end

    def emit_expression
      if @output_mode
        emit_literal('#{CGI.escapeHTML((')
        yield
        emit_literal(').to_s)}')
      else
        yield
      end
    end

    def flush_emit_buffer
      return if !@emit_buffer

      @code_buffer << "#{'  ' * @level}__buf__ << \"#{@emit_buffer}\"\n"
      @emit_buffer = nil
      true
    end

    def emit_code(code)
      if flush_emit_buffer || @line_break
        emit_code_line_break if @line_break
        @code_buffer << "#{'  ' * @level}#{code}"
      else
        if @code_buffer.empty? || (@code_buffer[-1] == "\n")
          @code_buffer << "#{'  ' * @level}#{code}"
        else
          @code_buffer << "#{code}"
        end
      end
    end

    def compile(template, initial_level = 0)
      @block = template.to_proc
      @level = initial_level
      ast = RubyVM::AbstractSyntaxTree.of(@block)
      Compiler.pp_ast(ast) if ENV['DEBUG'] == '1'
      @level += 1
      parse(ast)
      flush_emit_buffer
      @level -= 1
      self
    end

    attr_reader :code_buffer

    def to_code
      pad = '  ' * @level
      "#{pad}->(__buf__, __ctx__#{args}) do\n#{prelude}#{@code_buffer}#{pad}  __buf__\n#{pad}end"
    end

    def args
      return nil if !@args
      
      ", #{@args.join(", ")}"
    end

    def prelude
      return nil if @sub_templates.empty?

      converted = @sub_templates.map { |t| convert_sub_template(t)}
      "#{'  ' * @level}  __sub_templates__ = [\n#{converted.join("\n")}\n  ]\n"
    end

    def convert_sub_template(template)
      template.compile(@level + 2).to_code
    end

    def to_proc
      @block.binding.eval(to_code)
    end

    def parse(node, line_break = true)
      @line_break = line_break && @last_node && node.first_lineno != @last_node.first_lineno
      @last_node = node
      method_name = :"parse_#{node.type.downcase}"
      if !respond_to?(method_name)
        raise Papercraft::Error, "Template compiler doesn't know how to convert #{node.type.inspect} node"
      end
      send(method_name, node)
    end

    def parse_scope(node)
      args = node.children[0]
      if args && !args.empty?
        @args = args
      end
      parse(node.children[2])
    end

    def parse_iter(node)
      call, scope = node.children
      if call.type == :FCALL
        parse_fcall(call, scope)
      else
        parse(call)
        emit_code(" do")
        args = scope.children[0]
        emit_code(" |#{args.join(', ')}|") if args
        emit_code("\n")
        @level += 1
        parse(scope)
        flush_emit_buffer
        @level -= 1
        emit_code("end\n")
      end
    end

    def parse_ivar(node)
      ivar = node.children.first.match(/^@(.+)*/)[1]
      emit_literal("__ctx__[:#{ivar}]")
    end

    def parse_fcall(node, block = nil)
      tag, args = node.children
      args = args.children.compact if args

      case tag
      when :html5
        return emit_html5(node, block)
      when :emit
        return emit_emit(args.first, block)
      when :text
        return emit_text_fcall(args.first)
      end

      text = fcall_inner_text_from_args(args)
      atts = fcall_attributes_from_args(args)
      if block
        emit_tag(tag, atts) { parse(block) }
      elsif text
        emit_tag(tag, atts) do
          case text
          when Papercraft::Template
            @sub_templates << text
            idx = @sub_templates.size - 1
            emit_code("__sub_templates__[#{idx}].(__buf__, __ctx__)\n")
          when String
            emit_output { emit_text(text) }
          when RubyVM::AbstractSyntaxTree::Node
            emit_output { emit_expression { parse(text) } }
          else
            emit_text(text.to_s)
          end
        end
      else
        emit_tag(tag, atts)
      end
    end

    def fcall_inner_text_from_args(args)
      return nil if !args

      first = args.first
      case first.type
      when :STR
        first.children.first
      when :LIT, :SYM
        first.children.first.to_s
      when :HASH
        nil
      when :CONST
        const_name = first.children.first
        value = get_const(const_name)
        if value.is_a?(Papercraft::Template)
          value
        else
          value
        end
      else
        first
      end
    end

    def fcall_attributes_from_args(args)
      return nil if !args

      last = args.last
      (last.type == :HASH) ? last : nil
    end

    def emit_html5(node, block = nil)
      emit_output do
        emit_literal('<!DOCTYPE html>')
      end
      emit_tag(:html, nil) { parse(block) } if block
    end

    def emit_tag(tag, atts, &block)
      emit_output do
        if atts
          emit_literal("<#{tag}")
          emit_tag_attributes(atts)
          emit_literal(block ? '>' : '/>')
        else
          emit_literal(block ? "<#{tag}>" : "<#{tag}/>")
        end
      end
      if block
        block.call
        emit_output { emit_literal("</#{tag}>") }
      end
    end

    def emit_emit(node, block)
      case node.type
      when :STR, :LIT, :SYM
        value = node.children.first.to_s
        emit_output { emit_literal(value) }
      when :VCALL
        emit_code("__buf__ << #{node.children.first}\n")
      when :CONST
        name = node.children.first.to_s
        value = get_const(name)
        case value
        when Papercraft::Template
          @sub_templates << value
          idx = @sub_templates.size - 1
          emit_code("__sub_templates__[#{idx}].(__buf__, __ctx__)\n")
        else
          emit_output { emit_literal(value) }
        end
      else
        raise NotImplementedError
      end

      # value = fcall_inner_text_from_args(args)
      # emit_output do
      #   emit_literal(value)
      # end
    end

    def emit_tag_attributes(atts)
      list = atts.children.first.children
      while true
        key = list.shift
        break unless key

        value = list.shift
        value_type = value.type
        case value_type
        when :FALSE, :NIL
          next
        end

        emit_literal(' ')
        emit_tag_attribute_key(key)
        next if value_type == :TRUE

        emit_literal('=\"')
        emit_tag_attribute_value(value, key)
        emit_literal('\"')
      end
    end

    def emit_tag_attribute_key(key)
      case key.type
      when :STR
        emit_literal(key.children.first)
      when :LIT, :SYM
        emit_literal(key.children.first.to_s)
      when :NIL
        emit_literal('nil')
      else
        emit_expression { parse(key) }
      end
    end

    def emit_tag_attribute_value(value, key)
      case value.type
      when :STR
        type = key.type
        is_href_attr = (type == :LIT || type == :SYM) && (key.children.first == :href)
        encoding = is_href_attr ? :uri : :html
        emit_text(value.children.first, encoding: encoding)
      when :LIT, :SYM
        emit_text(value.children.first.to_s)
      else
        parse(value)
      end
    end

    def parse_call(node)
      receiver, method, args = node.children
      if receiver.type == :VCALL && receiver.children == [:context]
        emit_literal('__ctx__')
      else
        parse(receiver)
      end
      if method == :[]
        emit_literal('[')
        args = args.children.compact
        while true
          arg = args.shift
          break unless arg

          parse(arg)
          emit_literal(', ') if !args.empty?
        end
        emit_literal(']')
      else
        emit_literal('.')
        emit_literal(method.to_s)
        if args
          emit_literal('(')
          args = args.children.compact
          while true
            arg = args.shift
            break unless arg

            parse(arg)
            emit_literal(', ') if !args.empty?
          end
          emit_literal(')')
        end
      end
    end

    def parse_str(node)
      str = node.children.first
      emit_literal(str.inspect)
    end

    def parse_lit(node)
      value = node.children.first
      emit_literal(value.inspect)
    end

    def parse_sym(node)
      value = node.children.first
      emit_literal(value.inspect)
    end

    def parse_true(node)
      emit_expression { emit_literal('true') }
    end

    def parse_false(node)
      emit_expression { emit_literal('true') }
    end

    def parse_list(node)
      emit_literal('[')
      items = node.children.compact
      while true
        item = items.shift
        break unless item

        parse(item)
        emit_literal(', ') if !items.empty?
      end
      emit_literal(']')
    end

    def parse_vcall(node)
      tag = node.children.first
      emit_tag(tag, nil)
    end

    def parse_opcall(node)
      left, op, right = node.children
      parse(left)
      emit_literal(" #{op} ")
      right.children.compact.each { |c| parse(c) }
    end

    def parse_block(node)
      node.children.each { |c| parse(c) }
    end

    def parse_begin(node)
      node.children.each { |c| parse(c) if c }
    end

    def parse_if(node)
      cond, then_branch, else_branch = node.children
      if @output_mode
        emit_if_output(cond, then_branch, else_branch)
      else
        emit_if_code(cond, then_branch, else_branch)
      end
    end

    def parse_unless(node)
      cond, then_branch, else_branch = node.children
      if @output_mode
        emit_unless_output(cond, then_branch, else_branch)
      else
        emit_unless_code(cond, then_branch, else_branch)
      end
    end

    def emit_if_output(cond, then_branch, else_branch)
      parse(cond)
      emit_literal(" ? ")
      parse(then_branch)
      emit_literal(" : ")
      if else_branch
        parse(else_branch)
      else
        emit_literal(nil)
      end
    end

    def emit_unless_output(cond, then_branch, else_branch)
      parse(cond)
      emit_literal(" ? ")
      if else_branch
        parse(else_branch)
      else
        emit_literal(nil)
      end
      emit_literal(" : ")
      parse(then_branch)
    end

    def emit_if_code(cond, then_branch, else_branch)
      emit_code('if ')
      parse(cond)
      emit_code("\n")
      @level += 1
      parse(then_branch)
      flush_emit_buffer
      @level -= 1
      if else_branch
        emit_code("else\n")
        @level += 1
        parse(else_branch)
        flush_emit_buffer
        @level -= 1
      end
      emit_code("end\n")
    end

    def emit_unless_code(cond, then_branch, else_branch)
      emit_code('unless ')
      parse(cond)
      emit_code("\n")
      @level += 1
      parse(then_branch)
      flush_emit_buffer
      @level -= 1
      if else_branch
        emit_code("else\n")
        @level += 1
        parse(else_branch)
        flush_emit_buffer
        @level -= 1
      end
      emit_code("end\n")
    end

    def parse_dvar(node)
      emit_literal(node.children.first.to_s)
    end

    def parse_case(node)
      value       = node.children[0]
      when_clause = node.children[1]
      emit_code("case ")
      parse(value)
      emit_code("\n")
      parse_when(when_clause)
      emit_code("end\n")
    end

    def parse_when(node)
      values      = node.children[0]
      then_clause = node.children[1]
      else_clause = node.children[2]

      emit_code('when ')
      last_value = nil
      emit_when_clause_values(values)
      emit_code("\n")
      @level += 1
      parse(then_clause)
      @level -= 1
      
      return if !else_clause

      if else_clause.type == :WHEN
        parse_when(else_clause)
      else
        emit_code("else\n")
        @level += 1
        @level -= 1
        parse(else_clause)
      end
    end

    def emit_when_clause_values(values)
      if values.type != :LIST
        raise Papercraft::Error, "Expected LIST node, found #{values.type} node"
      end

      idx = 0
      list_items = values.children
      while idx < list_items.size
        value = list_items[idx]
        break if !value

        emit_code(', ') if idx > 0
        parse(value, idx > 0)
        idx += 1
      end
    end

    def self.pp_ast(node, level = 0)
      case node
      when RubyVM::AbstractSyntaxTree::Node
        puts "#{'  ' * level}#{node.type.inspect}"
        node.children.each { |c| pp_ast(c, level + 1) }
      when Array
        puts "#{'  ' * level}["
        node.each { |c| pp_ast(c, level + 1) }
        puts "#{'  ' * level}]"
      else
        puts "#{'  ' * level}#{node.inspect}"
        return
      end
    end
  end
end
