# frozen_string_literal: true

require 'papercraft'
require 'tilt'
require 'digest/sha1'

# Tilt.
module Tilt
  # Papercraft templating engine for Tilt
  class PapercraftTemplate < Template
    module SiropExtension
      # We override the Sirop get source in order to have access to the template
      # source code when the template is compiled.
      def get_source(fn)
        return Tilt::PapercraftTemplate.file_load(fn) if fn.match(/@tilt\-/)

        super
      end
    end
    ::Sirop.singleton_class.prepend(SiropExtension)

    # "File system" for storing template source code
    @@file_store = {}
    def self.file_save(fn, data) = @@file_store[fn] = data
    def self.file_load(fn) = @@file_store[fn]

    metadata[:mime_type] = 'text/html'

    protected

    def prepare
      src = <<~RUBY
        # frozen_string_literal: true
        -> (scope:, locals:, block:) {
          #{data}
        }
      RUBY
      fn = "@tilt-#{Digest::SHA1.hexdigest(src)}"
      PapercraftTemplate.file_save(fn, src)
      @template = eval(src, binding, fn)
    end

    def evaluate(scope, locals, &block)
      Papercraft.html(
        @template, scope: scope, locals: locals, block: block
      )
    end
  end

  register(PapercraftTemplate, 'papercraft')
end
