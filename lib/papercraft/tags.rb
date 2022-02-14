# frozen_string_literal: true

module Papercraft  
  # Markup (HTML/XML) extensions
  module Tags
    S_LT              = '<'
    S_GT              = '>'
    S_LT_SLASH        = '</'
    S_SPACE_LT_SLASH  = ' </'
    S_SLASH_GT        = '/>'
    S_SPACE           = ' '
    S_EQUAL_QUOTE     = '="'
    S_QUOTE           = '"'

    # The tag method template below is optimized for performance. Do not touch!

    S_TAG_METHOD_LINE = __LINE__ + 2
    S_TAG_METHOD = <<~EOF
      S_TAG_%<TAG>s_PRE = %<tag_pre>s
      S_TAG_%<TAG>s_CLOSE = %<tag_close>s

      def %<tag>s(text = nil, **props, &block)
        if text.is_a?(Hash) && props.empty?
          props = text
          text = nil
        end

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

    INITIAL_BUFFER_CAPACITY = 8192

    # Initializes a tag renderer.
    def initialize(&template)
      @buffer = String.new(capacity: INITIAL_BUFFER_CAPACITY)
      super
    end

    # Returns the rendered template.
    #
    # @return [String]
    def to_s
      if @parts
        last = @buffer
        @buffer = String.new(capacity: INITIAL_BUFFER_CAPACITY)
        parts = @parts
        @parts = nil
        parts.each do |p|
          if Proc === p
            render_deferred_proc(&p)
          else
            @buffer << p
          end
        end
        @buffer << last unless last.empty?
      end
      @buffer
    end

    # Defers the given block to be evaluated later. Deferred evaluation allows
    # Papercraft templates to inject state into sibling components, regardless
    # of the component's order in the container component. For example, a nested
    # component may set an instance variable used by another component. This is
    # an elegant solution to the problem of setting the XML page's title, or
    # adding elements to the `<head>` section. Here's how a title can be
    # controlled from a nested component:
    #
    #   layout = Papercraft.html {
    #     html {
    #       head {
    #         defer { title @title }
    #       }
    #       body {
    #         emit_yield
    #       }
    #     }
    #   }
    #
    #   html.render {
    #     @title = 'My super page'
    #     h1 'content'
    #   }
    #
    # @param &block [Proc] Deferred block to be emitted
    # @return [void]
    def defer(&block)
      if !@parts
        @parts = [@buffer, block]
      else
        @parts << @buffer unless @buffer.empty?
        @parts << block
      end
      @buffer = String.new(capacity: INITIAL_BUFFER_CAPACITY)
    end
    
    
    # Emits an XML tag with the given content, properties and optional block.
    # This method is an alternative to emitting XML tags using dynamically
    # created methods. This is particularly useful when using extensions that
    # have method names that clash with XML tags, such as `button` or `a`, or
    # when you need to override the behaviour of a particular XML tag.
    #
    # The following two method calls have the same effect:
    #
    # button 'text', id: 'button1'
    # tag :button, 'text', id: 'button1'
    #
    # @param sym [Symbol, String] XML tag
    # @param text [String, nil] tag content
    # @param **props [Hash] tag attributes
    # @param &block [Proc] optional inner XML
    # @return [void]
    def tag(sym, text = nil, **props, &block)
      if text.is_a?(Hash) && props.empty?
        props = text
        text = nil
      end

      tag = tag_repr(sym)

      @buffer << S_LT << tag
      emit_props(props) unless props.empty?

      if block
        @buffer << S_GT
        instance_eval(&block)
        @buffer << S_LT_SLASH << tag << S_GT
      elsif Proc === text
        @buffer << S_GT
        emit(text)
        @buffer << S_LT_SLASH << tag << S_GT
      elsif text
        @buffer << S_GT << escape_text(text.to_s) << S_LT_SLASH << tag << S_GT
      else
        @buffer << S_SLASH_GT
      end
    end

    # Catches undefined tag method call and handles it by defining the method.
    #
    # @param sym [Symbol] XML tag or component identifier
    # @param args [Array] method arguments
    # @param opts [Hash] named method arguments
    # @param &block [Proc] block passed to method
    # @return [void]
    def method_missing(sym, *args, **opts, &block)
      tag = sym.to_s
      repr = tag_repr(tag)
      code = S_TAG_METHOD % {
        tag: tag,
        TAG: tag.upcase,
        tag_pre: "<#{repr}".inspect,
        tag_close: "</#{repr}>".inspect
      }
      self.class.class_eval(code, __FILE__, S_TAG_METHOD_LINE)
      send(sym, *args, **opts, &block)
    end

    # Emits text into the rendering buffer, escaping any special characters to
    # the respective XML entities.
    #
    # @param data [String] text
    # @return [void]
    def text(data)
      @buffer << escape_text(data)
    end

    private

    # Emits an arbitrary object by converting it to string, then adding it to
    # the internal buffer. This method is called internally by `Renderer#emit`.
    #
    # @param obj [Object] emitted object
    # @return [void]
    def emit_object(obj)
      @buffer << obj.to_s
    end

    # Renders a deferred proc by evaluating it, then adding the rendered result
    # to the buffer.
    #
    # @param &block [Proc] deferred proc
    # @return [void]
    def render_deferred_proc(&block)
      old_buffer = @buffer
      
      @buffer = String.new(capacity: INITIAL_BUFFER_CAPACITY)
      @parts = nil

      instance_eval(&block)

      old_buffer << to_s
      @buffer = old_buffer
    end

    # Escapes text. This method must be overriden in Renderers which include
    # this module.
    #
    # @param text [String] text to be escaped
    def escape_text(text)
      raise NotImplementedError
    end

    # Converts a tag to its string representation. This method must be overriden
    # in Renderers which include this module.
    #
    # @param tag [Symbol, String] tag
    def tag_repr(tag)
      raise NotImplementedError
    end

    # Converts an attribute to its string representation. This method must be
    # overriden in Renderers which include this module.
    #
    # @param att [Symbol, String] attribute
    def att_repr(att)
      raise NotImplementedError
    end

    # Emits tag attributes into the rendering buffer.
    #
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
            @buffer << S_SPACE << att_repr(k)
          when false, nil
            # emit nothing
          else
            @buffer << S_SPACE << att_repr(k) <<
              S_EQUAL_QUOTE << v << S_QUOTE
          end
        end
      }
    end
  end
end
