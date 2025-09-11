# 2.12 2025-09-11

- Add support for injecting location attributes into HTML tags (for debug purposes)

# 2.11 2025-09-11

- Add mode param to `P2::Template` wrapper class

# 2.10 2025-09-11

- Add support for rendering XML, implement `Proc#render_xml`
- Fix handling of literal strings with double quotes
- Improve error handling for `P2::Error` exceptions

# 2.9 2025-09-02

- Tweak generated code to incorporate @byroot's
  [recommendations](https://www.reddit.com/r/ruby/comments/1mtj7bx/comment/n9ckbvt/):
  - Remove call to to_s coercion before calling html_escape
  - Chain calls to `#<<` with emitted HTML parts

# 2.8 2025-08-17

- Add `#render_children` builtin
- Rename `#emit_yield` to `#render_yield`
- Add `Proc#render_cached` for caching render result

# 2.7 2025-08-17

- Improve source maps and whitespace in compiled code
- Minor improvements to emit_yield generated code
- Add support for extensions

# 2.6 2025-08-16

- Add support for block invocation

# 2.5 2025-08-15

- Translate backtrace for exceptions raised in `#render_to_buffer`
- Improve display of backtrace when source map is missing entries
- Improve handling of ArgumentError raised on calling the template
- Add `Template#apply`, `Template#compiled_proc` methods

# 2.4 2025-08-10

- Add P2::Template wrapper class

# 2.3 2025-08-10

- Fix whitespace issue in visit_yield_node
- Reimplement and optimize exception backtrace translation
- Minor improvement to code generation

# 2.2 2025-08-09

- Update docs
- Refactor code

# 2.1 2025-08-08

- Optimize output code: directly invoke component templates instead of calling
  `P2.render_emit_call`. P2 is now
- Optimize output code: use separate pushes to buffer instead of interpolated
  strings.
- Streamline API: `emit proc` => `render`, `emit str` => `raw`, `emit_markdown`
  => `markdown`
- Optimize output code: add `frozen_string_literal` to top of compiled code
- Add more benchmarks (#1)
- Optimize output code: use ERB::Escape.html_escape instead of CGI.escape_html
  (#2)
- Fix source map calculation

## 2.0.1 2025-08-07

- Fix source map calculation

## 2.0 2025-08-07

- Passes all HTML, compilation tests from Papercraft
- Automatic compilation
- Plain procs/lambdas as templates
- Remove everything not having to do with HTML
- P2: compiled functional templates - they're super fast!
