# frozen_string_literal: true

module P2
  # Represents a tag call
  class TagNode
    attr_reader :call_node, :location, :tag, :tag_location, :inner_text, :attributes, :block

    def initialize(call_node, translator)
      @call_node = call_node
      @location = call_node.location
      @tag = call_node.name
      prepare_block(translator)

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

    def prepare_block(translator)
      @block = call_node.block
      if @block.is_a?(Prism::BlockNode)
        @block = translator.visit(@block)
        offset = @location.start_offset
        length = @block.opening_loc.start_offset - offset
        @tag_location = @location.copy(start_offset: offset, length: length)
      else
        @tag_location = @location
      end
    end
  end

  # Represents a render call
  class RenderNode
    attr_reader :call_node, :location, :block

    include Prism::DSL

    def initialize(call_node, translator)
      @call_node = call_node
      @location = call_node.location
      @translator = translator
      @block = call_node.block && translator.visit(call_node.block)

      lambda = call_node.arguments && call_node.arguments.arguments[0]
    end

    def ad_hoc_string_location(str)
      src = source(str)
      Prism::DSL.location(source: src, start_offset: 0, length: str.bytesize)
    end

    def transform(node)
      node && @translator.visit(node)
    end

    def transform_array(array)
      array ? array.map { @translator.visit(it) } : []
    end

    def accept(visitor)
      visitor.visit_render_node(self)
    end
  end

  # Represents a text call
  class TextNode
    attr_reader :call_node, :location

    def initialize(call_node, _translator)
      @call_node = call_node
      @location = call_node.location
    end

    def accept(visitor)
      visitor.visit_text_node(self)
    end
  end

  # Represents a raw call
  class RawNode
    attr_reader :call_node, :location

    def initialize(call_node, _translator)
      @call_node = call_node
      @location = call_node.location
    end

    def accept(visitor)
      visitor.visit_raw_node(self)
    end
  end

  # Represents a defer call
  class DeferNode
    attr_reader :call_node, :location, :block

    def initialize(call_node, translator)
      @call_node = call_node
      @location = call_node.location
      @block = call_node.block && translator.visit(call_node.block)
    end

    def accept(visitor)
      visitor.visit_defer_node(self)
    end
  end

  # Represents a builtin call
  class BuiltinNode
    attr_reader :tag, :call_node, :location, :block

    def initialize(call_node, translator)
      @call_node = call_node
      @tag = call_node.name
      @location = call_node.location
      @block = call_node.block && translator.visit(call_node.block)
    end

    def accept(visitor)
      visitor.visit_builtin_node(self)
    end
  end
end
