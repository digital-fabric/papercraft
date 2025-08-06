# frozen_string_literal: true

require_relative './compiler'

# Extensions to the Proc class
class ::Proc
  def compiled_code
    P2::TemplateCompiler.compile_to_code(self)
  end

  def compiled?
    @is_compiled
  end

  def compiled!
    @is_compiled = true
    self
  end

  def compiled_proc
    @compiled_proc ||= @is_compiled ? self : compile
  end
  
  def compile
    P2.compile(self).compiled!
  rescue Sirop::Error
    uncompiled_renderer
  end

  def render(*a, **b, &c)
    # p render: { a:, b:, c:}
    compiled_proc.(+'', *a, **b, &c)
  end

  def render_to_buffer(buf, *a, **b, &c)
    compiled_proc.(buf, *a, **b, &c)
  end

  def uncompiled_renderer
    ->(__buffer__, *a, **b, &c) {
      P2::UncompiledProcWrapper.new(self).call(__buffer__, *a, **b, &c)
      __buffer__
    }.compiled!
  end

  def apply(*a, **b, &c)
    compiled = compiled_proc
    c_compiled = c&.compiled_proc
    
    ->(__buffer__, *x, **y, &z) {
      c_proc = c_compiled && ->(__buffer__, *d, **e) {
        # Kernel.p(
        #   c_proc: 1,
        #   a:, b:, c:, d:, e:, z:
        # )      
        c_compiled.(__buffer__, *a, *d, **b, **e, &z)
      }.compiled!
      
      # Kernel.p(
      #   apply: 1,
      #   a:, b:, c:, x:, y:, z:
      # )      
      compiled.(__buffer__, *a, *x, **b, **y, &c_proc)
    }.compiled!
  end
end

module P2
  def self.compile(proc)
    P2::TemplateCompiler.compile(proc)
  end

  class UncompiledProcWrapper
    def initialize(proc)
      @proc = proc
    end

    def call(buffer, *a, **b)
      @buffer = buffer
      instance_exec(*a, **b, &@proc)
    end

    def method_missing(sym, *a, **b, &c)
      tag(sym, *a, **b, &c)
    end

    def p(*a, **b, &c)
      tag(:p, *a, **b, &c)
    end

    def tag(sym, *a, **b, &block)
      @buffer << "<#{sym}>"
      if block
        instance_eval(&block)
      end
      @buffer << "</#{sym}>"
    end
  end
end
