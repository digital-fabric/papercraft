<h1 align="center">
  <img src="papercraft.png">
  <br>
  Papercraft
</h1>

<h4 align="center">Functional HTML templating for Ruby</h4>

<p align="center">
  <a href="http://rubygems.org/gems/papercraft">
    <img src="https://badge.fury.io/rb/papercraft.svg" alt="Ruby gem">
  </a>
  <a href="https://github.com/digital-fabric/papercraft/actions/workflows/test.yml">
    <img src="https://github.com/digital-fabric/papercraft/actions/workflows/test.yml/badge.svg" alt="Tests">
  </a>
  <a href="https://github.com/digital-fabric/papercraft/blob/master/LICENSE">
    <img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="MIT License">
  </a>
</p>

<p align="center">
  <a href="https://www.rubydoc.info/gems/papercraft">API reference</a>
</p>

## What is Papercraft?

```ruby
require 'papercraft'

page = ->(**props) {
  html {
    head { title 'My Title' }
    body { render_yield **props }
  }
}
page.render {
  p 'foo'
}
#=> "<html><head><title>Title</title></head><body><p>foo</p></body></html>"
```

Papercraft is a templating engine for dynamically producing HTML in Ruby apps. Papercraft
templates are expressed as Ruby procs, leading to easier debugging, better
protection against HTML injection attacks, and better code reuse.

Papercraft templates can be composed in a variety of ways, facilitating the usage of
layout templates, and enabling a component-oriented approach to building web
interfaces of arbitrary complexity.

In Papercraft, dynamic data is passed explicitly to the template as block/lambda
arguments, making the data flow easy to follow and understand. Papercraft also lets
developers create derivative templates using full or partial parameter
application.

```ruby
require 'papercraft'

page = ->(**props) {
  html {
    head { title 'My Title' }
    body { yield **props }
  }
}
page.render {
  p(class: 'big') 'foo'
}
#=> "<html><head><title>Title</title></head><body><p class="big">foo</p></body></html>"

hello_page = page.apply ->(name:, **) {
  h1 "Hello, #{name}!"
}
hello.render(name: 'world')
#=> "<html><head><title>Title</title></head><body><h1>Hello, world!</h1></body></html>"
```

Papercraft features:

- Express HTML using plain Ruby procs.
- Automatic compilation for super-fast execution (about as
  [fast](https://github.com/digital-fabric/papercraft/blob/master/examples/perf.rb) as
  compiled ERB/ERubi).
- Deferred rendering using `defer`.
- Simple and easy template composition (for uses such as layouts, or modular
  templates).
- Markdown rendering using [Kramdown](https://github.com/gettalong/kramdown/).
- Support for extensions.
- Simple caching API for caching the rendering result.

## Table of Content

- [Getting Started](#getting-started)
- [Basic Markup](#basic-markup)
- [Builtin Methods](#builtin-methods)
- [Template Parameters](#template-parameters)
- [Template Logic](#template-logic)
- [Template Blocks](#template-blocks)
- [Template Composition](#template-composition)
- [Parameter and Block Application](#parameter-and-block-application)
- [Higher-Order Templates](#higher-order-templates)
- [Layout Template Composition](#layout-template-composition)
- [Emitting Markdown](#emitting-markdown)
- [Deferred Evaluation](#deferred-evaluation)
- [Cached Rendering](#cached-rendering)

A typical example for a dashboard-type app markup can be found here:
https://github.com/digital-fabric/papercraft/blob/master/examples/dashboard.rb

## Getting Started

In Papercraft, an HTML template is expressed as a proc:

```ruby
html = -> {
  div(id: 'greeter') { p 'Hello!' }
}
```

Rendering a template is done using `Proc#render`:

```ruby
require 'papercraft'

html.render #=> "<div id="greeter"><p>Hello!</p></div>"
```

## Basic Markup

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

### Tag and Attribute Formatting

Papercraft does not make any assumption about what tags and attributes you can use. You
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

### Escaping Content

Papercraft automatically escapes all text content emitted in a template. The specific
escaping algorithm depends on the template type. To emit raw HTML, use the
`#raw` method as [described below](#builtin-methods).

## Builtin Methods

In addition to normal tags, Papercraft provides the following method calls for templates:

### `#text` - emit escaped text

`#text` is used for emitting text that will be escaped. This method can be used
to emit text not directly inside an enclosing tag:

```ruby
-> {
  p {
    text 'The time is: '
    span(Time.now, id: 'clock')
  }
}.render #=> <p>The time is: <span id="clock">XX:XX:XX</span></p>
```

### `#raw` - emit raw HTML

`#raw` is used for emitting raw HTML, i.e. without escaping. You can use this to
emit an HTML snippet:

```ruby
TITLE_HTML = '<h1>hi</h1>'
-> {
  div {
    raw TITLE_HTML
  }
}.render #=> <div><h1>hi</h1></div>
```

### `#render_yield` - emit given block

`#render_yield` is used to emit a given block. If no block is given, a
`LocalJumpError` exception is raised:

```ruby
Card = ->(**props) {
  card { render_yield(**props) }
}

Card.render(foo: 'bar') { |foo|
  h1 foo
} #=> <card><h1>bar</h1></card>
```

`render_yield` can be called with or without arguments, which are passed to the
given block.

### `#render_children` - emit given block

`#render_children` is used to emit a given block, but does not raise an
exception if no block is given.

### `#defer` - emit deferred HTML

`#defer` is used to emit HTML in a deferred fashion - the deferred part will be
evaluated only after processing the entire template:

```ruby
Layout = -> {
  head {
    defer {
      title @title
    }
  }
  body {
    render_yield
  }
}

Layout.render {
  @title = 'Foobar'
  h1 'hi'
} #=> <head><title>Foobar</title></head><body><h1>hi</h1></body>
```

### `#render` - render the given template inline

`#render` is used to emit the given template. This can be used to compose
templates:

```ruby
partial = -> { p 'foo' }
-> {
  div {
    render partial
  }
}.render #=> <div><p>foo</p></div>
```

Any argument following the given template is passed to the template for
rendering:

```ruby
large_button = ->(title) { button(title, class: 'large') }

-> {
  render large_button, 'foo'
}.render #=> <button class="large">foo</button>
```

### `#html5` - emit an HTML5 document type declaration and html tag

```ruby
-> {
  html5 {
    p 'hi'
  }
} #=> <!DOCTYPE html><html><p>hi</p></html>
```

### `#markdown` emit markdown content

`#markdown` is used for rendering markdown content. The call converts the given
markdown to HTML and emits it into the rendered HTML:

```ruby
-> {
  div {
    markdown 'This is *markdown*'
  }
}.render #=> <p>This is <em>markdown</em></p>
```

## Template Parameters

In Papercraft, parameters are always passed explicitly. This means that template
parameters are specified as block parameters, and are passed to the template on
rendering:

```ruby
greeting = ->(name) { h1 "Hello, #{name}!" }
greeting.render('world') #=> "<h1>Hello, world!</h1>"
```

Templates can also accept named parameters:

```ruby
greeting = ->(name:) { h1 "Hello, #{name}!" }
greeting.render(name: 'world') #=> "<h1>Hello, world!</h1>"
```

## Template Logic

Since Papercraft templates are just a bunch of Ruby, you can easily embed your view
logic right in the template:

```ruby
->(user = nil) {
  if user
    span "Hello, #{user.name}!"
  else
    span "Hello, guest!"
  end
}
```

## Template Blocks

Templates can also accept and render blocks by using `render_yield`:

```ruby
page = -> {
  html {
    body { render_yield }
  }
}

# we pass the inner HTML
page.render { h1 'hi' }
```

## Template Composition

Papercraft makes it easy to compose multiple templates into a whole HTML document. A Papercraft
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

page = ->(title, items) {
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
non-constant templates by invoking the `#render` method:

```ruby
greeting = -> { span "Hello, world" }

-> {
  div {
    render greeting
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
div_wrap = -> { div { render_yield } }
wrapped_h1 = div_wrap.apply { h1 'hi' }
wrapped_h1.render #=> "<div><h1>hi</h1></div>"

# wrap a template
wrapped_hello_world = div_wrap.apply(&hello_world)
wrapped_hello_world.render #=> "<div><h1>Hello, world!</h1></div>"
```

## Higher-Order Templates

Papercraft also lets you create higher-order templates, that is, templates that take
other templates as parameters, or as blocks. Higher-order templates are handy
for creating layouts, wrapping templates in arbitrary markup, enhancing
templates or injecting template parameters.

Here is a higher-order template that takes a template as parameter:

```ruby
div_wrap = -> { |inner| div { render inner } }
greeter = -> { h1 'hi' }
wrapped_greeter = div_wrap.apply(greeter)
wrapped_greeter.render #=> "<div><h1>hi</h1></div>"
```

The inner template can also be passed as a block, as shown above:

```ruby
div_wrap = -> { div { render_yield } }
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
      render_yield(**params)
    }
  }
}

article_layout = default_layout.apply { |title:, body:|
  article {
    h1 title
    markdown body
  }
}

article_layout.render(
  title: 'This is a title',
  body: 'Hello from *markdown body*'
)
```

## Emitting Markdown

Markdown is rendered using the
[Kramdown](https://kramdown.gettalong.org/index.html) gem. To emit Markdown, use
`#markdown`:

```ruby
template = -> { |md| div { markdown md } }
template.render("Here's some *Markdown*") #=> "<div><p>Here's some <em>Markdown</em><p>\n</div>"
```

[Kramdown
options](https://kramdown.gettalong.org/options.html#available-options) can be
specified by adding them to the `#markdown` call:

```ruby
template = -> { |md| div { markdown md, auto_ids: false } }
template.render("# title") #=> "<div><h1>title</h1></div>"
```

You can also use `Papercraft.markdown` directly:

```ruby
Papercraft.markdown('# title') #=> "<h1>title</h1>"
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
`Papercraft.default_kramdown_options`, e.g.:

```ruby
Papercraft.default_kramdown_options[:auto_ids] = false
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
deps = DependencyMananger.new

default_layout = -> { |**args|
  head {
    defer { render deps.head_markup }
  }
  body { render_yield **args }
}

button = proc { |text, onclick|
  deps.js '/static/js/button.js'
  deps.css '/static/css/button.css'

  button text, onclick: onclick
}

heading = proc { |text|
  deps.js '/static/js/heading.js'
  deps.css '/static/css/heading.css'

  h1 text
}

page = default_layout.apply {
  render heading, "What's your favorite cheese?"

  render button, 'Beaufort', 'eat_beaufort()'
  render button, 'Mont d''or', 'eat_montdor()'
  render button, 'Époisses', 'eat_epoisses()'
}
```

## Cached Rendering

Papercraft provides a simple API for caching the result of a rendering. The cache stores
renderings of a template respective to the given arguments. To automatically
retrieve the cached rendered HTML, or generate it for the first time, use
`Proc#render_cached`:

```ruby
template = ->(title) { div { h1 title } }
template.render_cached('foo') #=> <div><h1>foo</h1></div>
template.render_cached('foo') #=> <div><h1>foo</h1></div> (from cache)
template.render_cached('bar') #=> <div><h1>bar</h1></div>
template.render_cached('bar') #=> <div><h1>bar</h1></div> (from cache)
```
