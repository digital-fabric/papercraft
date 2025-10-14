# frozen_string_literal: true

require_relative './compiler'

module Papercraft
  # Extensions to the Proc class.
  module ProcExtensions
    # Returns true if proc is marked as compiled.
    #
    # @return [bool] is the proc marked as compiled
    def __compiled__?
      @__compiled__
    end

    # Marks the proc as compiled, i.e. can render directly and takes a string
    # buffer as first argument.
    #
    # @return [self]
    def __compiled__!
      @__compiled__ = true
      self
    end

    # Returns the compiled proc for the given proc. If marked as compiled, returns
    # self.
    #
    # @param mode [Symbol] compilation mode (:html, :xml)
    # @return [Proc] compiled proc or self
    def __compiled_proc__(mode: :html)
      @__compiled_proc__ ||= @__compiled__ ? self : Papercraft.compile(self, mode:)
    end

    # Renders the proc to HTML with the given arguments.
    #
    # @return [String] HTML string
    def render(*a, **b, &c)
      __compiled_proc__.(+'', *a, **b, &c)
    rescue Exception => e
      e.is_a?(Papercraft::Error) ? raise : raise(Papercraft.translate_backtrace(e))
    end

    # Renders the proc to XML with the given arguments.
    #
    # @return [String] XML string
    def render_xml(*a, **b, &c)
      __compiled_proc__(mode: :xml).(+'', *a, **b, &c)
    rescue Exception => e
      e.is_a?(Papercraft::Error) ? raise : raise(Papercraft.translate_backtrace(e))
    end

    # Returns a proc that applies the given arguments to the original proc. The
    # returned proc calls the *compiled* form of the proc, merging the
    # positional and keywords parameters passed to `#apply` with parameters
    # passed to the applied proc. If a block is given, it is wrapped in a proc
    # that passed merged parameters to the block.
    #
    # @param *pos1 [Array<any>] applied positional parameters
    # @param **kw1 [Hash<any, any] applied keyword parameters
    # @return [Proc] applied proc
    def apply(*pos1, **kw1, &block)
      compiled = __compiled_proc__
      c_compiled = block&.__compiled_proc__

      ->(__buffer__, *pos2, **kw2, &block2) {
        c_proc = c_compiled && ->(__buffer__, *pos3, **kw3) {
          c_compiled.(__buffer__, *pos3, **kw3, &block2)
        }.__compiled__!

        compiled.(__buffer__, *pos1, *pos2, **kw1, **kw2, &c_proc)
      }.__compiled__!
    end

    # Caches and returns the rendered HTML for the template with the given
    # arguments.
    #
    # @param key [any] Cache key
    # @return [String] HTML string
    def render_cache(key, *args, **kargs, &block)
      @render_cache ||= {}
      @render_cache[key] ||= render(*args, **kargs, &block)
    end
  end
end

::Proc.prepend(Papercraft::ProcExtensions)
