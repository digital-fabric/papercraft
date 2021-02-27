# frozen_string_literal: true

require 'escape_utils'

# A Rubyoshka is a template representing a piece of HTML
class Rubyoshka
  # A Renderer is a rendering of a Rubyoshka
  class Renderer
    attr_reader :context
  
    # Initializes attributes and renders the given block
    # @param context [Hash] rendering context
    # @param block [Proc] template block
    # @return [void]
    def initialize(context, &block)
      @context = context
      @buffer = +''
      instance_eval(&block)
    end
  
    # Returns the result of the rendering
    # @return [String]
    def to_s
      @buffer
    end

    def escape_text(text)
      raise NotImplementedError
    end

    def escape_uri(uri)
      EscapeUtils.escape_uri(v)
    end

    S_TAG_METHOD_LINE = __LINE__ + 1
    S_TAG_METHOD = <<~EOF
      S_TAG_%<TAG>s_PRE = '<%<tag>s'
      S_TAG_%<TAG>s_CLOSE = '</%<tag>s>'
      
      def %<tag>s(text = nil, **props, &block)
        @buffer << S_TAG_%<TAG>s_PRE
        emit_props(props) unless props.empty?
      
        if block
          @buffer << S_GT
          instance_eval(&block)
          @buffer << S_TAG_%<TAG>s_CLOSE
        elsif Rubyoshka === text
          @buffer << S_GT
          emit(text)
          @buffer << S_TAG_%<TAG>s_CLOSE
        elsif text
          @buffer << S_GT << escape_text(text.to_s) << S_TAG_%<TAG>s_CLOSE
        else
          @buffer << S_SLASH_GT
        end
      end
    EOF

    R_CONST_SYM = /^[A-Z]/
  
    # Catches undefined tag method call and handles them by defining the method
    # @param sym [Symbol] HTML tag or component identifier
    # @param args [Array] method call arguments
    # @param block [Proc] block passed to method call
    # @return [void]
    def method_missing(sym, *args, &block)
      value = @local && @local[sym]
      return value if value

      if sym =~ R_CONST_SYM
        # Component reference (capitalized method name)
        o = instance_eval(sym.to_s) rescue Rubyoshka.const_get(sym) \
            rescue Object.const_get(sym)
        case o
        when ::Proc
          self.class.define_method(sym) { |*a, &b| emit(o.(*a, &b)) }
          emit(o.(*args, &block))
        when Rubyoshka
          self.class.define_method(sym) { |**ctx|
            ctx.empty? ? emit(o) : with(ctx) { emit(o) }
          }
          ctx = args.first
          Hash === ctx ? with(ctx) { emit(o) } : emit(o)
        when ::String
          @buffer << o
        else
          e = StandardError.new "Cannot render #{o.inspect}"
          e.set_backtrace(caller)
          raise e
        end
      else
        tag = sym.to_s
        code = S_TAG_METHOD % { tag: tag, TAG: tag.upcase }
        self.class.class_eval(code, __FILE__, S_TAG_METHOD_LINE)
        send(sym, *args, &block)
      end
    end
  
    # Emits the given object into the rendering buffer
    # @param o [Proc, Rubyoshka, Module, String] emitted object
    # @return [void]
    def emit(o)
      case o
      when ::Proc
        instance_eval(&o)
      when Rubyoshka
        instance_eval(&o.block)
      when Module
        # If module is given, the component is expected to be a const inside the module
        emit(o::Component)
      when nil
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

    # Emits tag attributes into the rendering buffer
    # @param props [Hash] tag attributes
    # @return [void]
    def emit_props(props)
      props.each { |k, v|
        case k
        when :src, :href
          @buffer << S_SPACE << k.to_s << S_EQUAL_QUOTE <<
            EscapeUtils.escape_uri(v) << S_QUOTE
        else
          case v
          when true
            @buffer << S_SPACE << k.to_s
          when false, nil
            # emit nothing
          else
            @buffer << S_SPACE << k.to_s << S_EQUAL_QUOTE << v << S_QUOTE
          end
        end
      }
    end

    # Emits the p tag (overrides Object#p)
    # @param text [String] text content of tag
    # @param props [Hash] tag attributes
    # @para block [Proc] nested HTML block
    # @return [void]
    def p(text = nil, **props, &block)
      method_missing(:p, text, **props, &block)
    end
  
    S_HTML5_DOCTYPE = '<!DOCTYPE html>'
  
    # Emits an HTML5 doctype tag and an html tag with the given block
    # @param block [Proc] nested HTML block
    # @return [void]
    def html5(&block)
      @buffer << S_HTML5_DOCTYPE
      self.html(&block)
    end

    # Emits text into the rendering buffer
    # @param data [String] text
    def text(data)
      @buffer << escape_text(data)
    end

    # Sets a local context for the given block
    # @param ctx [Hash] context hash
    # @param block [Proc] nested HTML block
    # @return [void]
    def with(**ctx, &block)
      old_local, @local = @local, ctx
      instance_eval(&block)
    ensure
      @local = old_local
    end

    # Caches the given block with the given arguments as cache key
    # @param vary [*Object] cache key
    # @param block [Proc] nested HTML block
    # @return [void]
    def cache(*vary, &block)
      key = [block.source_location, *vary]

      if (cached = Rubyoshka.cache[key])
        @buffer << cached
        return
      end

      cache_pos = @buffer.length
      instance_eval(&block)
      diff = @buffer[cache_pos..-1]
      Rubyoshka.cache[key] = diff
    end
  end

  class HTMLRenderer < Renderer
    def escape_text(text)
      EscapeUtils.escape_html(text.to_s)
    end

  end

  class XMLRenderer < Renderer
    def escape_text(text)
      EscapeUtils.escape_xml(text.to_s)
    end
  end

  attr_reader :block

  # Initializes a Rubyoshka with the given block
  # @param ctx [Hash] local context
  # @param block [Proc] nested HTML block
  # @param [void]
  def initialize(mode: :html, **ctx, &block)
    @mode = mode
    @block = ctx.empty? ? block : proc { with(ctx, &block) }
  end

  H_EMPTY = {}.freeze

  # Renders the associated block and returns the string result
  # @param context [Hash] context
  # @return [String]
  def render(context = H_EMPTY)
    renderer_class.new(context, &block).to_s
  end

  def renderer_class
    case @mode
    when :html
      HTMLRenderer
    when :xml
      XMLRenderer
    else
      raise "Invalid mode #{@mode.inspect}"
    end
  end

  @@cache = {}

  def self.cache
    @@cache
  end

  def self.component(&block)
    proc { |*args| new { instance_exec(*args, &block) } }
  end
end

module ::Kernel
  # Convenience method for creating a new Rubyoshka
  # @param ctx [Hash] local context
  # @param block [Proc] nested block
  # @return [Rubyoshka] Rubyoshka template
  def H(**ctx, &block)
    Rubyoshka.new(ctx, &block)
  end
end