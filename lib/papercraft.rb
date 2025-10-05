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

  # Registry of Papercraft exgtensions
  Extensions = {}

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
end
