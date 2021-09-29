# frozen_string_literal: true

require_relative './html'

class Rubyoshka
  # A Renderer is a rendering of a Rubyoshka
  class Renderer
    attr_reader :context

    # Initializes attributes and renders the given block
    # @param context [Hash] rendering context
    # @param block [Proc] template block
    # @return [void]
    def initialize(context, template)
      @context = context
      @buffer = +''
      instance_eval(&template)
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
    def method_missing(sym, *args, **opts, &block)
      value = @local && @local[sym]
      return value if value

      if sym =~ R_CONST_SYM
        # Component reference (capitalized method name)
        o = instance_eval(sym.to_s) rescue Rubyoshka.const_get(sym) \
            rescue Object.const_get(sym)
        case o
        when ::Proc
          self.class.define_method(sym) { |*a, **c, &b| emit(o.(*a, **c, &b)) }
          emit(o.(*args, **opts, &block))
        when Rubyoshka
          self.class.define_method(sym) do |**ctx|
            ctx.empty? ? emit(o) : with(**ctx) { emit(o) }
          end
          Hash === opts.empty? ? emit(o) : with(**opts) { emit(o) }
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
        send(sym, *args, **opts, &block)
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
        instance_eval(&o.template)
      when Module
        # If module is given, the component is expected to be a const inside the module
        emit(o::Component)
      when nil
      else
        @buffer << o.to_s
      end
    end
    alias_method :e, :emit

    def emit_yield
      block = @context[:__block__]
      raise LocalJumpError, "no block given (emit_yield)" unless block

      instance_eval(&block)
    end

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
    def cache(*vary, **opts, &block)
      key = [block.source_location.hash, vary.hash, opts.hash]

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
    include HTML

    def escape_text(text)
      EscapeUtils.escape_html(text.to_s)
    end
  end

  class XMLRenderer < Renderer
    def escape_text(text)
      EscapeUtils.escape_xml(text.to_s)
    end
  end
end
