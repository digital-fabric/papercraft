# frozen_string_literal: true

require_relative '../papercraft'

module Papercraft
  module ProcAPI
    def ast
      Papercraft.ast(self)
    end

    def compiled_code
      Papercraft.compiled_code(self)
    end

    def to_html(*, **, &)
      Papercraft.html(self, *, **, &)
    end

    def to_xml(*, **, &)
      Papercraft.xml(self, *, **, &)
    end

    def apply(*, **, &)
      Papercraft.apply(self, *, **, &)
    end
  end
end

::Proc.prepend(Papercraft::ProcAPI)
