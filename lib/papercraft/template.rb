# frozen_string_literal: true

module Papercraft
  # Template wrapper class. This class can be used to distinguish between Papercraft
  # templates and other kinds of procs.
  class Template
    attr_reader :proc, :mode

    # @param proc [Proc] template proc
    # @param mode [Symbol] mode (:html, :xml)
    def initialize(proc, mode: :html)
      @proc = proc
      @mode = mode
    end

    def render(*, **, &)
      (mode == :xml) ? Papercraft.render_xml(@proc, *, **, &) : Papercraft.render(@proc, *, **, &)
    end

    def apply(*, **, &)
      Template.new(Papercraft.apply(@proc, *, **, &), mode: @mode)
    end

    def __compiled_proc__
      @proc.__compiled_proc__(mode: @mode)
    end
  end
end
