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
      (mode == :xml) ? @proc.render_xml(*, **, &) : @proc.render(*, **, &)
    end

    def apply(*, **, &)
      Template.new(@proc.apply(*, **, &), mode: @mode)
    end
    
    def compiled_proc
      @proc.compiled_proc(mode: @mode)
    end
  end
end
