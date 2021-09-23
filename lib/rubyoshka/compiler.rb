# frozen_string_literal: true

class Rubyoshka
  # The Compiler class compiles Rubyoshka templates
  class Compiler
    def self.compile_template_proc_code(template)
      ast = RubyVM::AbstractSyntaxTree.of(template.block)
      template_ast_to_ruby_code(ast)
    end

    def self.pp_node(node, level = 0)
      case node
      when RubyVM::AbstractSyntaxTree::Node
        puts "#{'  ' * level}#{node.type.inspect}"
        node.children.each { |c| pp_node(c, level + 1) }
      when Array
        puts "#{'  ' * level}["
        node.each { |c| pp_node(c, level + 1) }
        puts "#{'  ' * level}]"
      else
        puts "#{'  ' * level}#{node.inspect}"
        return
      end
    end
    
    def self.template_ast_to_ruby_code(ast)
      # pp_node(ast)
      instructions = template_ast_to_instructions(ast)
      # puts '*' * 40
      # pp instructions
      "->(__buffer__) {\n#{convert_instructions_to_ruby(instructions)}}"
    end

    def self.convert_instructions_to_ruby(instructions, level = 1)
      String.new(capacity: 4096).tap do |buffer|
        translate_instructions(instructions, buffer, level)
      end
    end

    def self.translate_instructions(instructions, buffer, level = 1)
      static = nil
      instructions.each do |i|
        case i
        when String
          static ? (static << i.inspect[1..-2]) : (static = i.inspect[1..-2])
        when Array # represents an interpolated expression
          code = "\#{#{i.first}}"
          static ? (static << code) : (static = code.dup)
        when Hash
          if static
            buffer << "#{'  ' * level}__buffer__ << \"#{static}\"\n"
            static = nil
          end
          send(:"translate_#{i[:type]}", i, buffer, level)
        else
          raise "Unsupported instruction type #{i.class}"
        end
      end
      if static
        buffer << "#{'  ' * level}__buffer__ << \"#{static}\"\n"
      end
      buffer
    end

    def self.translate_if(if_hash, buffer, level)
      then_part = translate_instructions(if_hash[:then], String.new(capacity: 4096), level + 1)
      else_part = translate_instructions(if_hash[:else], String.new(capacity: 4096), level + 1)
      buffer << "#{'  ' * level}if (#{if_hash[:cond]})\n#{then_part}#{'  ' * level}else\n#{else_part}#{'  ' * level}end\n"
    end

    def self.template_ast_to_instructions(ast)
      [].tap { |a| convert_ast_to_instructions(ast, a) }
    end

    def self.convert_ast_to_instructions(ast, instructions)
      case ast
      when RubyVM::AbstractSyntaxTree::Node
        case (type = ast.type)
        when :SCOPE
          convert_ast_to_instructions(ast.children[2], instructions)
        when :BLOCK
          ast.children.each { |c| convert_ast_to_instructions(c, instructions) }
        else
          send(:"convert_#{ast.type.downcase}", ast, instructions)
        end
      when Array
        ast.each { |c| convert_ast_to_instructions(c, instructions) }
      when nil
        # ignore
      else
        raise "Unsupported node class #{ast.class}"
      end
    end

    def self.convert_fcall(ast, instructions)
      c = ast.children
      tag = c[0]
      args = convert_fcall_args(c[1])
      if args.empty?
        instructions << "<#{tag}/>"
      else
        text, hash = args
        if hash
          instructions << "<#{tag} #{convert_tag_hash(hash)}>"
        else
          instructions << "<#{tag}>"
        end
        instructions << text
        instructions << "</#{tag}>"
      end
    end

    def self.convert_tag_hash(hash)
      parts = []
      items = hash.children
      idx = 0
      while true
        item = items[idx]
        break unless item

        k = item.children[0]
        v = items[idx + 1].children[0]
        parts << "#{k}=\"#{v}\""
        idx += 2
      end
      parts.join(' ')
    end

    def self.convert_fcall_args(ast)
      ast.children.map do |c|
        next unless c
        case c.type
        when :STR
          c.children.first
        when :HASH
          c.children.first
        when :IF
          convert_fcall_if_arg(c)
        else
          raise "Unsupported fcall_arg #{c.type}"
        end
      end
    end

    def self.convert_fcall_if_arg(ast)
      c = ast.children
      ["(#{c[0].children[0]}) ? (#{c[1].children[0].inspect}) : (#{c[2].children[0].inspect})"]
    end

    def self.convert_if(node, instructions)
      c = node.children
      cond = c[0].children[0]
      then_instructions = []
      convert_ast_to_instructions(c[1], then_instructions)
      else_instructions = []
      convert_ast_to_instructions(c[2], else_instructions)

      instructions << {
        type: :if,
        cond: cond,
        then: then_instructions,
        else: else_instructions
      }
    end
  end
end
