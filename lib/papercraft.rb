# frozen_string_literal: true

require 'escape_utils'

require_relative 'papercraft/component'
require_relative 'papercraft/renderer'
require_relative 'papercraft/encoding'
# require_relative 'papercraft/compiler'

# Papercraft is a component-based HTML templating library
module Papercraft
  # Exception class used to signal templating-related errors
  class Error < RuntimeError; end
end

# Kernel extensions
module ::Kernel
  # Convenience method for creating a new Papercraft
  # @param ctx [Hash] local context
  # @param template [Proc] template block
  # @return [Papercraft] Papercraft template
  def H(&template)
    Papercraft::Component.new(&template)
  end

  def X(&template)
    Papercraft::Component.new(mode: :xml, &template)
  end
end
