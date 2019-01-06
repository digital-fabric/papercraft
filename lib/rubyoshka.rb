# frozen_string_literal: true

require 'modulation/gem'
require 'escape_utils'

export_default :Rubyoshka

class Rubyoshka
  class Rendering
    attr_reader :context
  
    def initialize(context, &block)
      @context = context
      @buffer = +''
      instance_eval(&block)
    end
  
    def to_s
      @buffer
    end
  
    S_TAG_METHOD = <<~EOF
      def %1$s(*args, &block)
        tag(:%1$s, *args, &block)
      end
    EOF

    R_CONST_SYM = /^[A-Z]/
  
    def method_missing(sym, *args, &block)
      if sym =~ R_CONST_SYM
        o = instance_eval(sym.to_s) rescue Rubyoshka.const_get(sym) \
            rescue Object.const_get(sym)
        case o
        when ::Proc
          self.class.define_method(sym) { |*a, &b| emit o.(*a, &b) }
          emit o.(*args, &block)
        when Rubyoshka
          self.class.define_method(sym) { emit o }
          emit(o)
        when ::String
          @buffer << o
        else
          e = StandardError.new "Cannot render #{o.inspect}"
          e.set_backtrace(caller)
          raise e
        end
      else
        self.class.class_eval(S_TAG_METHOD % sym)
        tag(sym, *args, &block)
      end
    end
  
    def emit(o)
      case o
      when ::Proc
        instance_eval(&o)
      when Rubyoshka
        instance_eval(&o.block)
      else
        @buffer << o.to_s
      end
    end
    alias_method :e, :emit
  
    S_LT              = '<'
    S_GT              = '>'
    S_LT_SLASH        = '</'
    S_SPACE_LT_SLASH  = ' </'
    S_SLASH_GT        = '/>'
    S_SPACE           = ' '
    S_EQUAL_QUOTE     = '="'
    S_QUOTE           = '"'
  
    def tag(sym, text = nil, **props, &block)
      sym = sym.to_s
  
      @buffer << S_LT << sym
      emit_props(props) unless props.empty?
  
      if block
        @buffer << S_GT
        instance_eval(&block)
        @buffer << S_LT_SLASH << sym << S_GT
      elsif Rubyoshka === text
        @buffer << S_GT
        emit(text)
        @buffer << S_LT_SLASH << sym << S_GT
      elsif text
        @buffer << S_GT << EscapeUtils.escape_html(text.to_s) <<
          S_LT_SLASH << sym << S_GT
      else
        @buffer << S_SLASH_GT
      end
    end

    E = EscapeUtils
  
    def emit_props(props)
      props.each { |k, v|
        case k
        when :text
        when :src, :href
          @buffer << S_SPACE << k.to_s << S_EQUAL_QUOTE <<
            E.escape_uri(v) << S_QUOTE
        else
          @buffer << S_SPACE << k.to_s << S_EQUAL_QUOTE << v << S_QUOTE
        end
      }
    end

    def p(text = nil, **props, &block)
      tag(:p, text, **props, &block)
    end
  
    S_HTML5_DOCTYPE = '<!DOCTYPE html>'
  
    def html5(&block)
      @buffer << S_HTML5_DOCTYPE
      self.html(&block)
    end

    def text(data)
      @buffer << EscapeUtils.escape_html(text)
    end
  end

  attr_reader :block

  def initialize(&block)
    @block = block
  end

  def render(context = {})
    Rendering.new(context, &block).to_s
  end
end

module ::Kernel
  def H(&block)
    Rubyoshka.new(&block)
  end
end