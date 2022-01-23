# frozen_string_literal: true

require 'json'

module Papercraft  
  # JSON renderer extensions
  module JSON
    def object_stack
      @object_stack ||= [nil]
    end

    def with_object(&block)
      object_stack << nil
      instance_eval(&block)
    end

    def verify_array_target
      case object_stack[-1]
      when nil
        object_stack[-1] = []
      when Hash
        raise "Mixing array and hash values"
      end
    end

    def verify_hash_target
      case object_stack[-1]
      when nil
        object_stack[-1] = {}
      when Array
        raise "Mixing array and hash values"
      end
    end

    def push_array_item(value)
      object_stack[-1] << value
    end

    def push_kv_item(key, value)
      object_stack[-1][key] = value
    end

    def enter_object(&block)
      object_stack << nil
      instance_eval(&block)
      object_stack.pop
    end

    def item(value = nil, &block)
      verify_array_target
      if block
        value = enter_object(&block)
      end
      push_array_item(value)
    end

    def kv(key, value, &block)
      verify_hash_target
      if block
        value = enter_object(&block)
      end
      push_kv_item(key, value)
    end

    def method_missing(sym, value = nil, &block)
      kv(sym, value, &block)
    end

    def to_s
      object_stack[0].to_json
    end
  end
end
