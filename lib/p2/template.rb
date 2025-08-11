# frozen_string_literal: true

module P2
  # Template wrapper class. This class can be used to distinguish between P2
  # templates and other kinds of procs.
  class Template
    attr_reader :proc
    def initialize(proc)  = @proc = proc
    def render(*, **, &)  = @proc.render(*, **, &)
    def apply(*, **, &)   = Template.new(@proc.apply(*, **, &))
    def compiled_proc     = @proc.compiled_proc
  end
end
