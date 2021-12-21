# frozen_string_literal: true

require 'escape_utils'

require_relative 'rubyoshka/component'
require_relative 'rubyoshka/renderer'
# require_relative 'rubyoshka/compiler'

# A Rubyoshka is a template representing a piece of HTML
module Rubyoshka
  class Error < RuntimeError
  end

  module Encoding
    def __html_encode__(text)
      EscapeUtils.escape_html(text.to_s)
    end

    def __uri_encode__(text)
      EscapeUtils.escape_uri(text.to_s)
    end
  end

  def self.component(&block)
    proc { |*args| Component.new { instance_exec(*args, &block) } }
  end
end
::H = Rubyoshka::Component

# Kernel extensions
module ::Kernel
  # Convenience method for creating a new Rubyoshka
  # @param ctx [Hash] local context
  # @param template [Proc] template block
  # @return [Rubyoshka] Rubyoshka template
  def H(**ctx, &template)
    Rubyoshka::Component.new(**ctx, &template)
  end
end

# Object extensions
class Object
  include Rubyoshka::Encoding
end
