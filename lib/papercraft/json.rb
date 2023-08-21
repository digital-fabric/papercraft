# frozen_string_literal: true

require 'json'

module Papercraft
  # JSON renderer extensions
  module JSON
    # Initializes a JSON renderer, setting up an object stack.
    def initialize(&template)
      @object_stack = [nil]
      super
    end

    # Adds an array item to the current object target. If a block is given, the
    # block is evaulated against a new object target, then added to the current
    # array.
    #
    #   Papercraft.json {
    #     item 'foo'
    #     item 'bar'
    #   }.render #=> "[\"foo\", \"bar\"]"
    #
    # @param value [Object] item
    # @return [void]
    def item(value = nil, _for: nil, &block)
      return _for.each { |*a| item(value) { block.(*a)} } if _for

      verify_array_target
      if block
        value = enter_object(&block)
      end
      push_array_item(value)
    end

    # Adds a key-value item to the current object target. If a block is given,
    # the block is evaulated against a new object target, then used as the
    # value.
    #
    # @param key [Object] key
    # @param value [Object] value
    # @return [void]
    def kv(key, value = nil, &block)
      verify_hash_target
      if block
        value = enter_object(&block)
      end
      push_kv_item(key, value)
    end

    # Intercepts method calls by adding key-value pairs to the current object
    # target.
    #
    # @param key [Symbol] key
    # @param value [Object] value
    # @return [void]
    def method_missing(key, value = nil, &block)
      kv(key, value, &block)
    end

    # Converts the root object target to JSON.
    #
    # @return [String] JSON template result
    def to_s
      @object_stack[0].to_json
    end

    private

    # Adds a new entry to the object stack and evaluates the given block.
    #
    # @return [void]
    def with_object(&block)
      @object_stack << nil
      instance_eval(&block)
    end

    # Verifies that the current object target is not a hash.
    #
    # @return [bool]
    def verify_array_target
      case @object_stack[-1]
      when nil
        @object_stack[-1] = []
      when Hash
        raise "Mixing array and hash values"
      end
    end

    # Verifies that the current object target is not an array.
    #
    # @return [bool]
    def verify_hash_target
      case @object_stack[-1]
      when nil
        @object_stack[-1] = {}
      when Array
        raise "Mixing array and hash values"
      end
    end

    # Pushes an array item to the current object target.
    #
    # @param value [Object] item
    # @return [void]
    def push_array_item(value)
      @object_stack[-1] << value
    end

    # Pushes a key value into the current object target.
    #
    # @param key [Object] key
    # @param value [Object] value
    # @return [void]
    def push_kv_item(key, value)
      @object_stack[-1][key] = value
    end

    # Adds a new object to the object stack, evaluates the given template block,
    # then pops the object off the stack.
    #
    # @return [void]
    def enter_object(&block)
      @object_stack << nil
      instance_eval(&block)
      @object_stack.pop
    end
  end
end
