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

  class RenderNode
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
      visitor.visit_render_node(self)
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

  class RawNode
    attr_reader :call_node, :location

    def initialize(call_node, _compiler)
      @call_node = call_node
      @location = call_node.location
    end

    def accept(visitor)
      visitor.visit_raw_node(self)
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

  class BuiltinNode
    attr_reader :tag, :call_node, :location, :block

    def initialize(call_node, compiler)
      @call_node = call_node
      @tag = call_node.name
      @location = call_node.location
      @block = call_node.block && compiler.visit(call_node.block)
    end

    def accept(visitor)
      visitor.visit_builtin_node(self)
    end
  end
end
