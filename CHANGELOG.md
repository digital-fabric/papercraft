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
