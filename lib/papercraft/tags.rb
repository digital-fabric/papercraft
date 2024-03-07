# frozen_string_literal: true

require_relative './extension_proxy'
require 'escape_utils'

module Papercraft
  # Markup (HTML/XML) extensions
  module Tags
    S_LT              = '<'
    S_GT              = '>'
    S_LT_SLASH        = '</'
    S_SPACE_LT_SLASH  = ' </'
    S_SLASH_GT        = '/>'
    S_GT_LT_SLASH     = '></'
    S_SPACE           = ' '
    S_EQUAL_QUOTE     = '="'
    S_QUOTE           = '"'

    # The tag method template below is optimized for performance. Do not touch!

    S_TAG_METHOD_LINE = __LINE__ + 2
    S_TAG_METHOD = <<~EOF
      S_TAG_%<TAG>s_PRE = %<tag_pre>s
      S_TAG_%<TAG>s_CLOSE = %<tag_close>s

      def %<tag>s(text = nil, _for: nil, **attributes, &block)
        return if @render_fragment && @fragment != @render_fragment

        return _for.each { |*a| %<tag>s(text, **attributes) { block.(*a)} } if _for

        if text.is_a?(Hash) && attributes.empty?
          attributes = text
          text = nil
        end

        @buffer << S_TAG_%<TAG>s_PRE
        emit_attributes(attributes) unless attributes.empty?

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
          @buffer << S_GT << S_TAG_%<TAG>s_CLOSE
        end
      end
    EOF

    S_VOID_TAG_METHOD_LINE = __LINE__ + 2
    S_VOID_TAG_METHOD = <<~EOF
      S_TAG_%<TAG>s_PRE = %<tag_pre>s
      S_TAG_%<TAG>s_CLOSE = %<tag_close>s

      def %<tag>s(text = nil, _for: nil, **attributes, &block)
        return if @render_fragment && @fragment != @render_fragment
        
        return _for.each { |*a| %<tag>s(text, **attributes) { block.(*a)} } if _for

        if text.is_a?(Hash) && attributes.empty?
          attributes = text
          text = nil
        end

        @buffer << S_TAG_%<TAG>s_PRE
        emit_attributes(attributes) unless attributes.empty?

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
    def initialize(render_fragment = nil, &template)
      @buffer = String.new(capacity: INITIAL_BUFFER_CAPACITY)
      super(render_fragment)
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
    # @param **attributes [Hash] tag attributes
    # @return [void]
    def tag(sym, text = nil, _for: nil, **attributes, &block)
      return if @render_fragment && @fragment != @render_fragment
        
      return _for.each { |*a| tag(sym, text, **attributes) { block.(*a)} } if _for

      if text.is_a?(Hash) && attributes.empty?
        attributes = text
        text = nil
      end

      tag = tag_repr(sym)

      @buffer << S_LT << tag
      emit_attributes(attributes) unless attributes.empty?

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
      elsif is_void_element_tag?(sym)
        @buffer << S_SLASH_GT
      else
        @buffer << S_GT_LT_SLASH << tag << S_GT
      end
    end

    # Catches undefined tag method call and handles it by defining the method.
    #
    # @param sym [Symbol] tag or component identifier
    # @param args [Array] method arguments
    # @param opts [Hash] named method arguments
    # @return [void]
    def method_missing(sym, *args, **opts, &block)
      tag = sym.to_s
      if tag =~ /^[A-Z]/ && (Object.const_defined?(tag))
        define_const_tag_method(tag)
      else
        define_tag_method(tag)
      end

      send(sym, *args, **opts, &block)
    end

    # Emits text into the rendering buffer, escaping any special characters to
    # the respective XML entities.
    #
    # @param data [String] text
    # @return [void]
    def text(data)
      return if @render_fragment && @fragment != @render_fragment
        
      @buffer << escape_text(data)
    end

    # Defines a custom tag. This is handy for defining helper or extension
    # methods inside the template body.
    #
    #   Papercraft.html {
    #     def_tag(:section) { |title, &inner|
    #       div {
    #         h1 title
    #         emit inner
    #       }
    #     }
    #
    #     section('Foo') {
    #       p 'Bar'
    #     }
    #   }
    #
    # @param tag [Symbol, String] tag/method name
    # @param block [Proc] method body
    # @return [void]
    def def_tag(tag, &block)
      self.class.define_method(tag, &block)
    end

    alias_method :orig_extend, :extend

    # Extends the template with the provided module or map of modules. When
    # given a module, the template body will be extended with the module,
    # and will have access to all the module's methods:
    #
    #   module CustomTags
    #     def label(text)
    #       span text, class: 'label'
    #     end
    #   end
    #
    #   Papercraft.html {
    #     extend CustomTags
    #     label('foo')
    #   }
    #
    # When given a hash, each module in the hash is namespaced, and can be
    # accessed using its key:
    #
    #   Papercraft.html {
    #     extend custom: CustomTags
    #     custom.label('foo')
    #   }
    #
    # @param ext [Module, Hash] extension module or hash mapping symbols to modules
    # @return [Object] self
    def extend(ext)
      if ext.is_a?(Module)
        orig_extend(ext)
      else
        ext.each do |sym, mod|
          define_extension_method(sym, mod)
        end
      end
    end

    private

    # Defines a method that emits the given tag based on a constant. The
    # constant must be defined on the main (Object) binding.
    #
    # @param tag [Symbol, String] tag/method name
    # @return [void]
    def define_const_tag_method(tag)
      const = Object.const_get(tag)
      self.class.define_method(tag) { |*a, **b, &blk|
        emit const, *a, **b, &blk
      }
    end

    # Defines a normal tag method.
    #
    # @param tag [Symbol, String] tag/method name
    # @return [void]
    def define_tag_method(tag)
      repr = tag_repr(tag)
      if is_void_element_tag?(tag)
        tmpl = S_VOID_TAG_METHOD
        line = S_VOID_TAG_METHOD_LINE
      else
        tmpl = S_TAG_METHOD
        line = S_TAG_METHOD_LINE
      end
      code = tmpl % {
        tag: tag,
        TAG: tag.upcase,
        tag_pre: "<#{repr}".inspect,
        tag_close: "</#{repr}>".inspect
      }
      self.class.class_eval(code, __FILE__, line)
    end

    # Defines a namespace referring to the given module.
    #
    # @param sym [Symbol] namespace
    # @param mod [Module] module
    # @return [void]
    def define_extension_method(sym, mod)
      self.singleton_class.define_method(sym) do
        (@extension_proxies ||= {})[mod] ||= ExtensionProxy.new(self, mod)
      end
    end

    # Emits an arbitrary object by converting it to string, then adding it to
    # the internal buffer. This method is called internally by `Renderer#emit`.
    #
    # @param obj [Object] emitted object
    # @return [void]
    def emit_object(obj)
      return if @render_fragment && @fragment != @render_fragment
        
      @buffer << obj.to_s
    end

    # Renders a deferred proc by evaluating it, then adding the rendered result
    # to the buffer.
    #
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
    # @param attributes [Hash] tag attributes
    # @return [void]
    def emit_attributes(attributes)
      attributes.each { |k, v|
        case v
        when true
          @buffer << S_SPACE << att_repr(k)
        when false, nil
          # emit nothing
        else
          v = v.join(S_SPACE) if v.is_a?(Array)
          @buffer << S_SPACE << att_repr(k) <<
            S_EQUAL_QUOTE << escape_text(v) << S_QUOTE
        end
      }
    end
  end
end
