# frozen_string_literal: true

require_relative 'papercraft/template'
require_relative 'papercraft/compiler'
require_relative 'papercraft/proc_ext'

# Papercraft is a functional templating library. In Papercraft, templates are expressed as plain
# Ruby procs.
module Papercraft
  # Exception class used to signal templating-related errors
  class Error < RuntimeError; end

  extend self

  # Registry of Papercraft extensions
  Extensions = {
    link_stylesheet: ->(href, **atts) {
      link(rel: "stylesheet", href:, **atts)
    }
  }

  # Registers extensions to the Papercraft syntax.
  #
  # @param spec [Hash] hash mapping symbols to procs
  # @return [self]
  def extension(spec)
    Extensions.merge!(spec)
    self
  end

  # Clears all registered extensions.
  #
  # @return [self]
  def __clear_extensions__
    Extensions.clear
    self
  end

  # Formats the given string, converting underscores to dashes.
  #
  # @param tag [String, Symbol] input string
  # @return [String] output string
  def underscores_to_dashes(tag)
    tag.to_s.gsub('_', '-')
  end

  # Formats the given hash as tag attributes.
  #
  # @param attrs [Hash] input hash
  # @return [String] formatted attributes
  def format_tag_attrs(attrs)
    attrs.each_with_object(+'') do |(k, v), html|
      case v
      when nil, false
      when true
        html << ' ' if !html.empty?
        html << underscores_to_dashes(k)
      else
        html << ' ' if !html.empty?
        v = v.join(' ') if v.is_a?(Array)
        html << "#{underscores_to_dashes(k)}=\"#{v}\""
      end
    end
  end

  # Translates entries in exception's backtrace to point to original source code.
  #
  # @param err [Exception] raised exception
  # @return [Exception] raised exception
  def translate_backtrace(err)
    cache = {}
    is_argument_error = err.is_a?(ArgumentError) && err.backtrace[0] =~ /^\:\:/
    backtrace = err.backtrace.map { |e| compute_backtrace_entry(e, cache) }

    return make_argument_error(err, backtrace) if is_argument_error

    err.set_backtrace(backtrace)
    err
  end

  # Computes a backtrace entry with caching.
  #
  # @param entry [String] backtrace entry
  # @param cache [Hash] cache store mapping compiled filename to source_map
  def compute_backtrace_entry(entry, cache)
    m = entry.match(/^((\:\:\(.+\:.+\))\:(\d+))/)
    return entry if !m

    fn = m[2]
    line = m[3].to_i
    source_map = cache[fn] ||= Compiler.source_map_store[fn]
    return entry if !source_map

    ref = source_map[line] || "?(#{line})"
    entry.sub(m[1], ref)
  end

  def make_argument_error(err, backtrace)
    m = err.message.match(/(given (\d+), expected (\d+))/)
    if m
      rectified = format('given %d, expected %d', m[2].to_i - 1, m[3].to_i - 1)
      message = err.message.gsub(m[1], rectified)
    else
      message = err.message
    end
    ArgumentError.new(message).tap { it.set_backtrace(backtrace) }
  end

  # Returns a Kramdown doc for the given markdown. The `opts` argument will be
  # merged with the default Kramdown options in order to change the rendering
  # behaviour.
  #
  # @param markdown [String] Markdown
  # @param opts [Hash] Kramdown option overrides
  # @return [Kramdown::Document] Kramdown document
  def markdown_doc(markdown, **opts)
    @markdown_deps_loaded ||= true.tap do
      require 'kramdown'
      require 'rouge'
      require 'kramdown-parser-gfm'
    end

    opts = default_kramdown_options.merge(opts)
    Kramdown::Document.new(markdown, **opts)
  end

  # Renders Markdown into HTML. The `opts` argument will be merged with the
  # default Kramdown options in order to change the rendering behaviour.
  #
  # @param markdown [String] Markdown
  # @param opts [Hash] Kramdown option overrides
  # @return [String] HTML
  def markdown(markdown, **opts)
    markdown_doc(markdown, **opts).to_html
  end

  # Returns the default Kramdown options used for rendering Markdown.
  #
  # @return [Hash] Kramdown options
  def default_kramdown_options
    @default_kramdown_options ||= {
      entity_output: :numeric,
      syntax_highlighter: :rouge,
      input: 'GFM',
      hard_wrap: false
    }
  end

  # Sets the default Kramdown options used for rendering Markdown.
  #
  # @param opts [Hash] Kramdown options
  # @return [Hash] Kramdown options
  def default_kramdown_options=(opts)
    @default_kramdown_options = opts
  end

  # Returns the compiled form code for the given proc.
  #
  # @param proc [Proc] template proc
  # @return [String] compiled proc code
  def compiled_code(proc)
    Papercraft::Compiler.compile_to_code(proc).last
  end

  # Returns the source map for the given proc.
  #
  # @param proc [Proc] template proc
  # @return [Array<String>] source map
  def source_map(proc)
    loc = proc.source_location
    fn = proc.__compiled__? ? loc.first : Papercraft::Compiler.source_location_to_fn(loc)
    Papercraft::Compiler.source_map_store[fn]
  end

  # Returns the AST for the given proc.
  #
  # @param proc [Proc] template proc
  # @return [Prism::Node] AST root
  def ast(proc)
    Sirop.to_ast(proc)
  end

  # Compiles the given template.
  #
  # @param proc [Proc] template proc
  # @param mode [Symbol] compilation mode (:html, :xml)
  # @return [Proc] compiled proc
  def compile(proc, mode: :html)
    Papercraft::Compiler.compile(proc, mode:).__compiled__!
  rescue Sirop::Error
    raise Papercraft::Error, "Can't compile eval'd template"
  end

  # Renders the given template to HTML with the given arguments.
  #
  # @param template [Proc] template proc
  # @return [String] HTML string
  def render(template, *a, **b, &c)
    template = template.proc if template.is_a?(Template)
    template.__compiled_proc__.(+'', *a, **b, &c)
  rescue Exception => e
    e.is_a?(Papercraft::Error) ? raise : raise(Papercraft.translate_backtrace(e))
  end
  alias_method :html, :render

  # Renders the proc to XML with the given arguments.
  #
  # @param template [Proc] template proc
  # @return [String] XML string
  def render_xml(template, *a, **b, &c)
    template = template.proc if template.is_a?(Template)
    template.__compiled_proc__(mode: :xml).(+'', *a, **b, &c)
  rescue Exception => e
    e.is_a?(Papercraft::Error) ? raise : raise(Papercraft.translate_backtrace(e))
  end

  # Returns a proc that applies the given arguments to the original proc. The
  # returned proc calls the *compiled* form of the proc, merging the
  # positional and keywords parameters passed to `#apply` with parameters
  # passed to the applied proc. If a block is given, it is wrapped in a proc
  # that passed merged parameters to the block.
  #
  # @param template [Proc] template proc
  # @param *pos1 [Array<any>] applied positional parameters
  # @param **kw1 [Hash<any, any] applied keyword parameters
  # @return [Proc] applied proc
  def apply(template, *pos1, **kw1, &block)
    template = template.proc if template.is_a?(Template)
    compiled = template.__compiled_proc__
    c_compiled = block&.__compiled_proc__

    ->(__buffer__, *pos2, **kw2, &block2) {
      c_proc = c_compiled && ->(__buffer__, *pos3, **kw3) {
        c_compiled.(__buffer__, *pos3, **kw3, &block2)
      }.__compiled__!

      compiled.(__buffer__, *pos1, *pos2, **kw1, **kw2, &c_proc)
    }.__compiled__!
  end

  # Caches and returns the rendered HTML for the template with the given
  # arguments.
  #
  # @param template [Proc] template proc
  # @param key [any] Cache key
  # @return [String] HTML string
  def render_cache(template, key, *args, **kargs, &block)
    template.__render_cache__[key] ||= render(template, *args, **kargs, &block)
  end

end
