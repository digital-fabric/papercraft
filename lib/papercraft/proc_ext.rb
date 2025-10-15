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

    # Returns the compiled proc for the proc. If marked as compiled, returns
    # self.
    #
    # @param mode [Symbol] compilation mode (:html, :xml)
    # @return [Proc] compiled proc or self
    def __compiled_proc__(mode: :html)
      @__compiled_proc__ ||= @__compiled__ ? self : Papercraft.compile(self, mode:)
    end

    # Returns the render cache for the proc.
    #
    # @return [Hash] cache hash
    def __render_cache__
      @__render_cache__ ||= {}
    end
  end
end

::Proc.prepend(Papercraft::ProcExtensions)
