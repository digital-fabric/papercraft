# frozen_string_literal: true

require_relative './compiler'

# Extensions to the Proc class.
class ::Proc
  # Returns the compiled form code for the proc.
  #
  # @return [String] compiled proc code
  def compiled_code
    P2::Compiler.compile_to_code(self).last
  end

  # Returns the source map for the compiled proc.
  #
  # @return [Array<String>] source map
  def source_map
    loc = source_location
    fn = compiled? ? loc.first : P2::Compiler.source_location_to_fn(loc)
    P2::Compiler.source_map_store[fn]
  end

  # Returns the AST for the proc.
  #
  # @return [Prism::Node] AST root
  def ast
    Sirop.to_ast(self)
  end

  # Returns true if proc is marked as compiled.
  #
  # @return [bool] is the proc marked as compiled
  def compiled?
    @is_compiled
  end

  # Marks the proc as compiled, i.e. can render directly and takes a string
  # buffer as first argument.
  #
  # @return [self]
  def compiled!
    @is_compiled = true
    self
  end

  # Returns the compiled proc for the given proc. If marked as compiled, returns
  # self.
  #
  # @return [Proc] compiled proc or self
  def compiled_proc
    @compiled_proc ||= @is_compiled ? self : compile
  end

  # Compiles the proc into the compiled form.
  #
  # @return [Proc] compiled proc
  def compile
    P2::Compiler.compile(self).compiled!
  rescue Sirop::Error
    raise P2::Error, "Dynamically defined procs cannot be compiled"
  end

  # Renders the proc to HTML with the given arguments.
  #
  # @return [String] HTML string
  def render(*a, **b, &c)
    compiled_proc.(+'', *a, **b, &c)
  rescue Exception => e
    e.is_a?(P2::Error) ? raise : raise(P2.translate_backtrace(e))
  end

  # Renders the proc to HTML with the given arguments into the given buffer.
  #
  # @param buf [String] buffer
  # @return [String] HTML string
  def render_to_buffer(buf, *a, **b, &c)
    compiled_proc.(buf, *a, **b, &c)
  rescue Exception => e
    raise P2.translate_backtrace(e)
  end

  # Returns a proc that applies the given arguments to the original proc.
  #
  # @return [Proc] applied proc
  def apply(*a, **b, &c)
    compiled = compiled_proc
    c_compiled = c&.compiled_proc

    ->(__buffer__, *x, **y, &z) {
      c_proc = c_compiled && ->(__buffer__, *d, **e) {
        c_compiled.(__buffer__, *a, *d, **b, **e, &z)
      }.compiled!

      compiled.(__buffer__, *a, *x, **b, **y, &c_proc)
    }.compiled!
  end

  # Caches and returns the rendered HTML for the template with the given
  # arguments.
  #
  # @return [String] HTML string
  def render_cached(*args, **kargs, &block)
    @render_cache ||= {}
    key = args.empty? && kargs.empty? && !block ? nil : [args, kargs, block&.source_location]
    @render_cache[key] ||= render(*args, **kargs, &block)
  end
end
