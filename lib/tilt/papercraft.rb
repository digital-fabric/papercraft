# frozen_string_literal: true

require 'papercraft'
require 'tilt'

# Tilt.
module Tilt
  # Papercraft templating engine for Tilt
  class PapercraftTemplate < Template
    metadata[:mime_type] = 'text/html'

    protected

    def prepare
      inner = eval("proc { |scope:, locals:, block:|\n#{data}\n}")
      @template = Papercraft.html(&inner)
    end

    def evaluate(scope, locals, &block)
      @template.render(scope: scope, locals: locals, block: block)
    end
  end

  register(PapercraftTemplate, 'papercraft')
end
