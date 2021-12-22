# frozen_string_literal: true

require_relative './html'

module Papercraft
  # A Renderer renders a Papercraft component into a string
  class Renderer
    class << self
      def verify_proc_parameters(template, args, named_args)
        param_count = 0
        template.parameters.each do |(type, name)|
          case type
          when :req
            param_count += 1
          when :keyreq
            if !named_args.has_key?(name)
              raise Papercraft::Error, "Missing template parameter #{name.inspect}"
            end
          end
        end
        if param_count > args.size
          raise Papercraft::Error, "Missing template parameters"
        end
      end  
    end

    attr_reader :context

    # Initializes attributes and renders the given block
    # @param context [Hash] rendering context
    # @param block [Proc] template block
    # @return [void]
    def initialize(&template)
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
      S_TAG_%<TAG>s_PRE = '<%<tag>s'.tr('_', '-')
      S_TAG_%<TAG>s_CLOSE = '</%<tag>s>'.tr('_', '-')

      def %<tag>s(text = nil, **props, &block)
        @buffer << S_TAG_%<TAG>s_PRE
        emit_props(props) unless props.empty?

        if block
          @buffer << S_GT
          instance_eval(&block)
          @buffer << S_TAG_%<TAG>s_CLOSE
        elsif Proc === text
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

    # Catches undefined tag method call and handles them by defining the method
    # @param sym [Symbol] HTML tag or component identifier
    # @param args [Array] method call arguments
    # @param block [Proc] block passed to method call
    # @return [void]
    def method_missing(sym, *args, **opts, &block)
      value = @local && @local[sym]
      return value if value

      tag = sym.to_s
      code = S_TAG_METHOD % { tag: tag, TAG: tag.upcase }
      self.class.class_eval(code, __FILE__, S_TAG_METHOD_LINE)
      send(sym, *args, **opts, &block)
    end

    # Emits the given object into the rendering buffer
    # @param o [Proc, Papercraft::Component, String] emitted object
    # @return [void]
    def emit(o, *a, **b)
      case o
      when ::Proc
        Renderer.verify_proc_parameters(o, a, b)
        instance_exec(*a, **b, &o)
      # when Papercraft::Component
      #   o = o.template
      #   Renderer.verify_proc_parameters(o, a, b)
      #   instance_exec(*a, **b, &o)
      when nil
      else
        @buffer << o.to_s
      end
    end
    alias_method :e, :emit

    def with_block(block, &run_block)
      old_block = @inner_block
      @inner_block = block
      instance_eval(&run_block)
    ensure
      @inner_block = old_block
    end
  
    def emit_yield(*a, **b)
      raise Papercraft::Error, "No block given" unless @inner_block
      
      instance_exec(*a, **b, &@inner_block)
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
            @buffer << S_SPACE << k.to_s.tr('_', '-')
          when false, nil
            # emit nothing
          else
            @buffer << S_SPACE << k.to_s.tr('_', '-') <<
              S_EQUAL_QUOTE << v << S_QUOTE
          end
        end
      }
    end

    # Emits text into the rendering buffer
    # @param data [String] text
    def text(data)
      @buffer << escape_text(data)
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
