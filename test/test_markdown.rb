# frozen_string_literal: true

require 'bundler/setup'
require 'minitest/autorun'
require 'papercraft'

class MarkdownTest < MiniTest::Test
  def test_basic_markdown
    templ = H { |md| body { emit_markdown(md) } }
    assert_equal "<body><h1 id=\"hi\">hi</h1>\n</body>",
      templ.render('# hi')

    templ = H { |md| body { emit_markdown(md) } }
    assert_equal "<body><p>Hello, <em>emphasis</em>.</p>\n</body>",
      templ.render('Hello, *emphasis*.')
  end

  def test_markdown_opts
    templ = H { |md| emit_markdown(md, auto_ids: false) }
    assert_equal "<h1>hi</h1>\n",
      templ.render('# hi')

    templ = H { |md| emit_markdown(md) }
    Papercraft::HTML.kramdown_options[:auto_ids] = false
    assert_equal "<h1>hi</h1>\n",
      templ.render('# hi')
  ensure
    Papercraft::HTML.kramdown_options.delete(:auto_ids)
  end

  def test_markdown_with_inline_code
    templ = H { |md| emit_markdown(md) }
    assert_equal "<p>Im calling <code>templ.render</code>.</p>\n",
      templ.render('I''m calling `templ.render`.')
  end

  def test_markdown_with_code_block
    templ = H { |md| emit_markdown(md) }
    assert_equal "<p>before</p>\n\n<div class=\"language-ruby highlighter-rouge\"><div class=\"highlight\"><pre class=\"highlight\"><code><span class=\"k\">def</span> <span class=\"nf\">foo</span><span class=\"p\">;</span> <span class=\"k\">end</span>\n</code></pre></div></div>\n\n<p>after</p>\n",
      templ.render("before\n\n```ruby\ndef foo; end\n```\n\nafter")
  end
end
