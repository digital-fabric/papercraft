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
