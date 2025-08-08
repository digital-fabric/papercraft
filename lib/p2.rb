# frozen_string_literal: true

require_relative 'p2/compiler'
require_relative 'p2/proc_ext'

# P2 is a composable templating library
module P2
  # Exception class used to signal templating-related errors
  class Error < RuntimeError; end

  extend self

  def format_tag(tag)
    tag.to_s.gsub('_', '-')
  end

  def format_html_attr_key(tag)
    tag.to_s.tr('_', '-')
  end
  
  def format_html_attrs(attrs)
    attrs.each_with_object(+'') do |(k, v), html|
      case v
      when nil, false
      when true
        html << ' ' if !html.empty?
        html << format_html_attr_key(k)
      else
        html << ' ' if !html.empty?
        v = v.join(' ') if v.is_a?(Array)
        html << "#{format_html_attr_key(k)}=\"#{v}\""
      end
    end
  end

  def render_emit_call(o, *a, **b, &block)
    case o
    when nil
      # do nothing
    when ::Proc
      o.render(*a, **b, &block)
    else
      o.to_s
    end
  end

  def translate_backtrace(e, source_map)
    re = compute_source_map_re(source_map)
    source_fn = source_map[:source_fn]
    backtrace = e.backtrace.map {
      if (m = it.match(re))
        line = m[2].to_i
        source_line = source_map[line] || "?(#{line})"
        it.sub(m[1], "#{source_fn}:#{source_line}")
      else
        it
      end
    }
    e.set_backtrace(backtrace)
  end

  def compute_source_map_re(source_map)
    escaped = source_map[:compiled_fn].gsub(/[\(\)]/) { "\\#{it[0]}" }
    /^(#{escaped}\:(\d+))/
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
  # @return [void]
  def default_kramdown_options=(opts)
    @default_kramdown_options = opts
  end
end
