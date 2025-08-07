<h1 align="center">
  <img src="p2.png">
  <br>
  P2
</h1>

<h4 align="center">Composable templating for Ruby</h4>

<p align="center">
  <a href="http://rubygems.org/gems/p2">
    <img src="https://badge.fury.io/rb/p2.svg" alt="Ruby gem">
  </a>
  <a href="https://github.com/digital-fabric/p2/actions?query=workflow%3ATests">
    <img src="https://github.com/digital-fabric/p2/workflows/Tests/badge.svg" alt="Tests">
  </a>
  <a href="https://github.com/digital-fabric/p2/blob/master/LICENSE">
    <img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="MIT License">
  </a>
</p>

<p align="center">
  <a href="https://www.rubydoc.info/gems/p2">API reference</a>
</p>

## What is P2?

P2 is a templating engine for dynamically producing HTML. P2 templates are
expressed as Ruby procs, leading to easier debugging, better protection against
HTML/XML injection attacks, and better code reuse.

P2 templates can be composed in a variety of ways, facilitating the usage of
layout templates, and enabling a component-oriented approach to building complex
web interfaces.

In P2, dynamic data is passed explicitly to the template as block arguments,
making the data flow easy to follow and understand. P2 also lets developers
create derivative templates using full or partial parameter application.

P2 includes built-in support for rendering Markdown (using
[Kramdown](https://github.com/gettalong/kramdown/)).

P2 automatically escapes all text emitted in templates according to the template
type. For more information see the section on [escaping
content](#escaping-content).

```ruby
require 'p2'

page = ->(**props) {
  html {
    head { title 'My Title' }
    body { yield **props }
  }
}
page.render {
  p 'foo'
}
#=> "<html><head><title>Title</title></head><body><p>foo</p></body></html>"

hello_page = page.apply ->(name:, **) {
  h1 "Hello, #{name}!"
}
hello.render(name: 'world')
#=> "<html><head><title>Title</title></head><body><h1>Hello, world!</h1></body></html>"
```

## Table of Content

- [Installing P2](#installing-p2)
- [Basic Usage](#basic-usage)
- [Adding Tags](#adding-tags)
- [Tag and Attribute Formatting](#tag-and-attribute-formatting)
- [Escaping Content](#escaping-content)
- [Template Parameters](#template-parameters)
- [Template Logic](#template-logic)
- [Template Blocks](#template-blocks)
- [Template Composition](#template-composition)
- [Parameter and Block Application](#parameter-and-block-application)
- [Higher-Order Templates](#higher-order-templates)
- [Layout Template Composition](#layout-template-composition)
- [Emitting Raw HTML](#emitting-raw-html)
- [Emitting a String with HTML Encoding](#emitting-a-string-with-html-encoding)
- [Emitting Markdown](#emitting-markdown)
- [Deferred Evaluation](#deferred-evaluation)
- [API Reference](#api-reference)

## Installing P2

**Note**: P2 requires Ruby version 3.4 or newer.

Using bundler:

```ruby
gem 'p2'
```

Or manually:

```bash
$ gem install p2
```

## Basic Usage

In P2, an HTML template is expressed as a proc:

```ruby
html = -> {
  div(id: 'greeter') { p 'Hello!' }
}
```

Rendering a template is done using `#render`:

```ruby
require 'p2'

html.render #=> "<div id="greeter"><p>Hello!</p></div>"
```

## Adding Tags

Tags are added using unqualified method calls, and can be nested using blocks:

```ruby
-> {
  html {
    head {
      title 'page title'
    }
    body {
      article {
        h1 'article title'
      }
    }
  }
}
```

Tag methods accept a string argument, a block, or no argument at all:

```ruby
-> { p 'hello' }.render #=> "<p>hello</p>"

-> { p { span '1'; span '2' } }.render #=> "<p><span>1</span><span>2</span></p>"

-> { hr() }.render #=> "<hr/>"
```

Tag methods also accept tag attributes, given as a hash:

```ruby
-> { img src: '/my.gif' }.render #=> "<img src=\"/my.gif\"/>"

-> { p "foobar", class: 'important' }.render #=> "<p class=\"important\">foobar</p>"
```

A `true` attribute value will emit a valueless attribute. A `nil` or `false`
attribute value will emit nothing:

```ruby
-> { button disabled: nil }.render #=> "<button></button>"
-> { button disabled: true }.render #=> "<button disabled></button>"
```

An attribute value given as an array will be joined by space characters:

```ruby
-> { div class: [:foo, :bar] }.render #=> "<div class=\"foo bar\"></div>"
```

## Tag and Attribute Formatting

P2 does not make any assumption about what tags and attributes you can use. You
can mix upper and lower case letters, and you can include arbitrary characters
in tag and attribute names. However, in order to best adhere to the HTML specs
and common practices, tag names and attributes will be formatted according to
the following rules, depending on the template type:

- HTML: underscores are converted to dashes:

  ```ruby
  -> {
    foo_bar { p 'Hello', data_name: 'world' }
  }.render #=> '<foo-bar><p data-name="world">Hello</p></foo-bar>'
  ```

If you need more precise control over tag names, you can use the `#tag` method,
which takes the tag name as its first parameter, then the rest of the parameters
normally used for tags:

```ruby
-> {
  tag 'cra_zy__:!tag', 'foo'
}.render #=> '<cra_zy__:!tag>foo</cra_zy__:!tag>'
```

## Escaping Content

P2 automatically escapes all text content emitted in a template. The specific
escaping algorithm depends on the template type. For HTML templates, P2 uses
[escape_utils](https://github.com/brianmario/escape_utils), specifically:

- HTML: `escape_utils.escape_html`

In order to emit raw HTML, you can use the `#emit` method as [described
below](#emitting-raw-html).

## Template Parameters

In P2, parameters are always passed explicitly. This means that template
parameters are specified as block parameters, and are passed to the template on
rendering:

```ruby
greeting = -> { |name| h1 "Hello, #{name}!" }
greeting.render('world') #=> "<h1>Hello, world!</h1>"
```

Templates can also accept named parameters:

```ruby
greeting = -> { |name:| h1 "Hello, #{name}!" }
greeting.render(name: 'world') #=> "<h1>Hello, world!</h1>"
```

## Template Logic

Since P2 templates are just a bunch of Ruby, you can easily embed your view
logic right in the template:

```ruby
-> { |user = nil|
  if user
    span "Hello, #{user.name}!"
  else
    span "Hello, guest!"
  end
}
```

## Template Blocks

Templates can also accept and render blocks by using `emit_yield`:

```ruby
page = -> {
  html {
    body { emit_yield }
  }
}

# we pass the inner HTML
page.render { h1 'hi' }
```

## Template Composition

P2 makes it easy to compose multiple templates into a whole HTML document. A P2
template can contain other templates, as the following example shows.

```ruby
Title = ->(title) { h1 title }

Item = ->(id:, text:, checked:) {
  li {
    input name: id, type: 'checkbox', checked: checked
    label text, for: id
  }
}

ItemList = ->(items) {
  ul {
    items.each { |i|
      Item(**i)
    }
  }
}

page = -> { |title, items|
  html5 {
    head { Title(title) }
    body { ItemList(items) }
  }
}

page.render('Hello from composed templates', [
  { id: 1, text: 'foo', checked: false },
  { id: 2, text: 'bar', checked: true }
])
```

In addition to using templates defined as constants, you can also use
non-constant templates by invoking the `#emit` method:

```ruby
greeting = -> { span "Hello, world" }

-> {
  div {
    emit greeting
  }
}
```

## Parameter and Block Application

Parameters and blocks can be applied to a template without it being rendered, by
using `#apply`. This mechanism is what allows template composition and the
creation of higher-order templates.

The `#apply` method returns a new template which applies the given parameters
and or block to the original template:

```ruby
# parameter application
hello = -> { |name| h1 "Hello, #{name}!" }
hello_world = hello.apply('world')
hello_world.render #=> "<h1>Hello, world!</h1>"

# block application
div_wrap = -> { div { emit_yield } }
wrapped_h1 = div_wrap.apply { h1 'hi' }
wrapped_h1.render #=> "<div><h1>hi</h1></div>"

# wrap a template
wrapped_hello_world = div_wrap.apply(&hello_world)
wrapped_hello_world.render #=> "<div><h1>Hello, world!</h1></div>"
```

## Higher-Order Templates

P2 also lets you create higher-order templates, that is, templates that take
other templates as parameters, or as blocks. Higher-order templates are handy
for creating layouts, wrapping templates in arbitrary markup, enhancing
templates or injecting template parameters.

Here is a higher-order template that takes a template as parameter:

```ruby
div_wrap = -> { |inner| div { emit inner } }
greeter = -> { h1 'hi' }
wrapped_greeter = div_wrap.apply(greeter)
wrapped_greeter.render #=> "<div><h1>hi</h1></div>"
```

The inner template can also be passed as a block, as shown above:

```ruby
div_wrap = -> { div { emit_yield } }
wrapped_greeter = div_wrap.apply { h1 'hi' }
wrapped_greeter.render #=> "<div><h1>hi</h1></div>"
```

## Layout Template Composition

One of the principal uses of higher-order templates is the creation of nested
layouts. Suppose we have a website with a number of different layouts, and we'd
like to avoid having to repeat the same code in the different layouts. We can do
this by creating a `default` page template that takes a block, then use `#apply`
to create the other templates:

```ruby
default_layout = -> { |**params|
  html5 {
    head {
      title: params[:title]
    }
    body {
      emit_yield(**params)
    }
  }
}

article_layout = default_layout.apply { |title:, body:|
  article {
    h1 title
    emit_markdown body
  }
}

article_layout.render(
  title: 'This is a title',
  body: 'Hello from *markdown body*'
)
```

## Emitting Raw HTML

Raw HTML can be emitted using `#emit`:

```ruby
wrapped = -> { |html| div { emit html } }
wrapped.render("<h1>hi</h1>") #=> "<div><h1>hi</h1></div>"
```

## Emitting a String with HTML Encoding

To emit a string with proper HTML encoding, without wrapping it in an HTML
element, use `#text`:

```ruby
-> { text 'hi&lo' }.render #=> "hi&amp;lo"
```

## Emitting Markdown

Markdown is rendered using the
[Kramdown](https://kramdown.gettalong.org/index.html) gem. To emit Markdown, use
`#emit_markdown`:

```ruby
template = -> { |md| div { emit_markdown md } }
template.render("Here's some *Markdown*") #=> "<div><p>Here's some <em>Markdown</em><p>\n</div>"
```

[Kramdown
options](https://kramdown.gettalong.org/options.html#available-options) can be
specified by adding them to the `#emit_markdown` call:

```ruby
template = -> { |md| div { emit_markdown md, auto_ids: false } }
template.render("# title") #=> "<div><h1>title</h1></div>"
```

You can also use `P2.markdown` directly:

```ruby
P2.markdown('# title') #=> "<h1>title</h1>"
```

The default Kramdown options are:

```ruby
{
  entity_output: :numeric,
  syntax_highlighter: :rouge,
  input: 'GFM',
  hard_wrap: false  
}
```

The deafult options can be configured by accessing
`P2.default_kramdown_options`, e.g.:

```ruby
P2.default_kramdown_options[:auto_ids] = false
```

## Deferred Evaluation

Deferred evaluation allows deferring the rendering of parts of a template until
the last moment, thus allowing an inner template to manipulate the state of the
outer template. To in order to defer a part of a template, use `#defer`, and
include any markup in the provided block. This technique, in in conjunction with
holding state in instance variables, is an alternative to passing parameters,
which can be limiting in some situations.

A few use cases for deferred evaulation come to mind:

- Setting the page title.
- Adding a flash message to a page.
- Using templates that dynamically add static dependencies (JS and CSS) to the
  page.

The last use case is particularly interesting. Imagine a `DependencyMananger`
class that can collect JS and CSS dependencies from the different templates
integrated into the page, and adds them to the page's `<head>` element:

```ruby
default_layout = -> { |**args|
  @dependencies = DependencyMananger.new
  head {
    defer { emit @dependencies.head_markup }
  }
  body { emit_yield **args }
}

button = proc { |text, onclick|
  @dependencies.js '/static/js/button.js'
  @dependencies.css '/static/css/button.css'

  button text, onclick: onclick
}

heading = proc { |text|
  @dependencies.js '/static/js/heading.js'
  @dependencies.css '/static/css/heading.css'

  h1 text
}

page = default_layout.apply {
  emit heading, "What's your favorite cheese?"

  emit button, 'Beaufort', 'eat_beaufort()'
  emit button, 'Mont d''or', 'eat_montdor()'
  emit button, 'Époisses', 'eat_epoisses()'
}
```

## HTML Utility methods

HTML templates include a few HTML-specific methods to facilitate writing modern
HTML:

- `html5 { ... }` - emits an HTML 5 DOCTYPE (`<!DOCTYPE html>`)
- `import_map(root_path, root_url)` - emits an import map including all files
  matching `<root_path>/*.js`, based on the given `root_url`
- `js_module(js)` - emits a `<script type="module">` element
- `link_stylesheet(href, **attributes)` - emits a `<link rel="stylesheet" ...>`
  element
- `script(js, **attributes)` - emits an inline `<script>` element
- `style(css, **attributes)` - emits an inline `<style>` element
- `versioned_file_href(href, root_path, root_url)` - calculates a versioned href
  for the given file

[HTML docs](https://www.rubydoc.info/gems/p2/P2/HTML)

## API Reference

The API reference for this library can be found
[here](https://www.rubydoc.info/gems/p2).
