# frozen_string_literal: true

require_relative 'p2/compiler'
require_relative 'p2/proc_ext'

# P2 is a functional templating library. In P2, templates are expressed as plain
# Ruby procs.
module P2
  # Exception class used to signal templating-related errors
  class Error < RuntimeError; end

  extend self

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

  # Translates an exceptions backtrace using a source map.
  #
  # @param exception [Exception] raised exception
  # @param source_map [Hash] source map
  #
  # @return [Exception] raised exception
  def translate_backtrace(exception)
    cache = {}
    backtrace = exception.backtrace.map { |e| compute_backtrace_entry(e, cache) }
    exception.set_backtrace(backtrace)
    exception
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

    source_line = source_map[line] || "?(#{line})"
    entry.sub(m[1], "#{source_map[:source_fn]}:#{source_line}")
  end

  # Renders Markdown into HTML. The `opts` argument will be merged with the
  # default Kramdown options in order to change the rendering behaviour.
  #
  # @param markdown [String] Markdown
  # @param opts [Hash] Kramdown option overrides
  # @return [String] HTML
  def markdown(markdown, **opts)
    # require relevant deps on use
    require 'kramdown'
    require 'rouge'
    require 'kramdown-parser-gfm'

    opts = default_kramdown_options.merge(opts)
    Kramdown::Document.new(markdown, **opts).to_html
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
