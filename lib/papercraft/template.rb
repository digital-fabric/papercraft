# frozen_string_literal: true

module Papercraft
  # Template wrapper class. This class can be used to distinguish between Papercraft
  # templates and other kinds of procs.
  class Template
    attr_reader :proc, :mode

    # @param proc [Proc] template proc
    # @param mode [Symbol] mode (:html, :xml)
    def initialize(proc = nil, mode: :html, &block)
      @proc = proc || block
      raise ArgumentError, "No template proc given" if !@proc

      @mode = mode
    end

    # Renders the template.
    #
    # @return [String] generated HTML
    def render(*, **, &)
      (mode == :xml) ? Papercraft.render_xml(@proc, *, **, &) : Papercraft.render(@proc, *, **, &)
    end
    alias_method :call, :render

    # Applies the given parameters and block to the template, returning an
    # applied template.
    #
    # @return [Papercraft::Template] applied template
    def apply(*, **, &)
      Template.new(Papercraft.apply(@proc, *, **, &), mode: @mode)
    end

    # Returns the compiled proc for the template.
    #
    # @return [Proc] compiled proc
    def __papercraft_compiled_proc
      @proc.__papercraft_compiled_proc(mode: @mode)
    end
  end
end
