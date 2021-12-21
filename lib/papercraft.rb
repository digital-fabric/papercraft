# frozen_string_literal: true

require 'escape_utils'

require_relative 'papercraft/component'
require_relative 'papercraft/renderer'
# require_relative 'papercraft/compiler'

# A Papercraft is a template representing a piece of HTML
module Papercraft
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
::H = Papercraft::Component

# Kernel extensions
module ::Kernel
  # Convenience method for creating a new Papercraft
  # @param ctx [Hash] local context
  # @param template [Proc] template block
  # @return [Papercraft] Papercraft template
  def H(**ctx, &template)
    Papercraft::Component.new(**ctx, &template)
  end
end

# Object extensions
class Object
  include Papercraft::Encoding
end
