# 3.0.1 2025-10-21

- Update Sirop, Prism dependencies

# 3.0.0 2025-10-19

- Improve implementation of `Papercraft.apply`
- Add support for rendering self-closing XML tags
- Streamline Papercraft API
- Add support for `Papercraft.render { ... }`
- Prefix internal Proc extensions with `__papercraft_`
- Change API to use `Papercraft.html` instead of `Proc#render`. Same for
  `apple`, `render_xml` etc.

# 2.24 2025-10-14

- Update gem links
- Simplify `render_cache`, caller must provide cache key
- Reduce surface area of Proc extensions

# 2.23 2025-10-12

- Update ERB to version 5.1.1

# 2.22 2025-10-08

- Use `prepend` instead of `include` to extend the `Proc` class

# 2.21 2025-10-08

- Fix `Proc#apply` parameter handling
- Put Proc extensions in separate module, included into Proc

# 2.20 2025-10-08

- Raise error on void element with child nodes or inner text
- Fix compilation of empty template

# 2.19 2025-10-08

- Use gem.coop in Gemfile

# 2.18 2025-10-08

- Add `link_stylesheet` extension
- Add support for rendering templates in IRB
- Update Sirop to 1.0

# 2.17 2025-10-05

- Update dependencies
- Add support for attributes in `html` tag
- Add `Papercraft.__clear__extensions__` method

# 2.16 2025-10-02

- Add support for namespaced components

# 2.15 2025-10-01

- Add `Papercraft.markdown_doc` method
- Emit DOCTYPE for `#html` as well as `#html5`

# 2.14 2025-09-17

- Do not escape inner text of style and script tags

# 2.13 2025-09-11

- Pass level to HTML debug attribute injection proc

# 2.12 2025-09-11

- Add support for injecting location attributes into HTML tags (for debug purposes)

# 2.11 2025-09-11

- Add mode param to `Papercraft::Template` wrapper class

# 2.10 2025-09-11

- Add support for rendering XML, implement `Proc#render_xml`
- Fix handling of literal strings with double quotes
- Improve error handling for `Papercraft::Error` exceptions

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

- Add Papercraft::Template wrapper class

# 2.3 2025-08-10

- Fix whitespace issue in visit_yield_node
- Reimplement and optimize exception backtrace translation
- Minor improvement to code generation

# 2.2 2025-08-09

- Update docs
- Refactor code

# 2.1 2025-08-08

- Optimize output code: directly invoke component templates instead of calling
  `Papercraft.render_emit_call`. Papercraft is now
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
- Papercraft: compiled functional templates - they're super fast!

## 1.4 2025-01-09

- Compiler: add support defer

## 1.3 2024-12-16

- Update dependencies

## 1.2 2023-08-21

- Update dependencies
- Implement template fragments

## 1.1 2023-07-03

- Add direct iteration using the `_for` attribute

## 1.0 2023-03-30

- Add support for Array attribute values

## 0.29 2023-03-11

- Add Tilt integration (#15)

## 0.28 2023-03-11

- Add `HTML#import_map`, `HTML#js_module` methods

## 0.27 2023-01-19

- Fix rendering of HTML void element tags

## 0.26 2023-01-13

- Add support for namespaced local extensions using `#extend`

## 0.25 2023-01-12

- Implement `#def_tag` for defining custom tags inline

## 0.24 2022-03-19

- Fix usage of const components (#13)
- Fix formatting of HTML/XML attributes for non-string values

## 0.23 2022-02-15

- Remove unused `Encoding` module
- Add SOAP extension (#11, thanks [@aemadrid](https://github.com/aemadrid))

## 0.22 2022-02-14

- Fix behaviour of call to `#p` in an extension (#10)

## 0.21 2022-02-13

- Refactor and improve documentation

## 0.20 2022-02-13

- Add support for XML namespaced tags and attributes (#9)
- Move and refactor HTML/XML common code to Tags module

## 0.19 2022-02-05

- Rename `Papercraft::Component` to `Papercraft::Template`

## 0.18 2022-02-04

- Cleanup and update examples
- Fix behaviour of #emit with block
- Improve README

## 0.17 2022-01-23

- Refactor markdown code, add `Papercraft.markdown` method (#8)

## 0.16 2022-01-23

- Implement JSON templating (#7)
- Add support for MIME types (#6)
- Change entrypoint from `Kernel#H`, `Kernel#X` to `Papercraft.html`, `.xml` (#5)

## 0.15 2022-01-20

- Fix tag method line reference
- Don't clobber ArgumentError exception

## 0.14 2022-01-19

- Add support for #emit_yield in applied component (#4)

## 0.13 2022-01-19

- Add support for partial parameter application (#3)

## 0.12 2022-01-06

- Improve documentation
- Add `Renderer#tag` method
- Add `HTML#style`, `HTML#script` methods

## 0.11 2022-01-04

- Add deferred evaluation

## 0.10.1 2021-12-25

- Fix tag rendering with empty text in Ruby 3.0

## 0.10 2021-12-25

- Add support for extensions

## 0.9 2021-12-23

- Add support for emitting Markdown
- Add support for passing proc as argument to `#H` and `#X`
- Deprecate `Encoding` module

## 0.8.1 2021-12-22

- Fix gemspec

## 0.8 2021-12-22

- Cleanup and refactor code
- Add Papercraft.xml global method for XML templates
- Make `Component` a descendant of `Proc`
- Introduce new component API
- Rename Rubyoshka to Papercraft
- Convert underscores to dashes for tag  and attribute names (@jaredcwhite)

## 0.7 2021-09-29

- Add `#emit_yield` for rendering layouts
- Add experimental template compilation (WIP)

## 0.6.1 2021-03-03

- Remove support for Ruby 2.6

## 0.6 2021-03-03

- Fix Rubyoshka on Ruby 3.0
- Refactor and add more tests

## 0.5 2021-02-27

- Add support for rendering XML
- Add Rubyoshka.component method
- Remove Modulation dependency

## 0.4 2019-02-05

- Add support for emitting component modules

## 0.3 2019-01-13

- Implement caching
- Improve performance
- Handle attributes with `false` value correctly

## 0.2 2019-01-07

- Better documentation
- Fix #text
- Add local context

## 0.1 2019-01-06

- First working version
