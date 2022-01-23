<h1 align="center">
  <img src="papercraft.png">
  <br>
  Papercraft
</h1>

<h4 align="center">Composable templating for Ruby</h4>

<p align="center">
  <a href="http://rubygems.org/gems/papercraft">
    <img src="https://badge.fury.io/rb/papercraft.svg" alt="Ruby gem">
  </a>
  <a href="https://github.com/digital-fabric/papercraft/actions?query=workflow%3ATests">
    <img src="https://github.com/digital-fabric/papercraft/workflows/Tests/badge.svg" alt="Tests">
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

page = Papercraft.html { |*args|
  html {
    head { }
    body { emit_yield *args }
  }
}
page.render { p 'foo' }
#=> "<html><head/><body><p>foo</p></body></html>"

hello = page.apply { |name| h1 "Hello, #{name}!" }
hello.render('world')
#=> "<html><head/><body><h1>Hello, world!</h1></body></html>"
```

Papercraft is a templating engine for Ruby that offers the following features:

- HTML, XML and JSON templating using plain Ruby syntax
- Minimal boilerplate
- Mix logic and tags freely
- Automatic HTML and XML escaping
- Composable components
- Standard or custom MIME types
- Explicit parameter passing to nested components
- Higher order components
- Built-in support for rendering [Markdown](#emitting-markdown)
- Support for namespaced extensions

## Installing Papercraft

Using bundler:

```ruby
gem 'papercraft'
```

Or manually:

```bash
$ gem install papercraft
```

## Getting started

To create a template use the global method `Kernel#H`:

```ruby
require 'papercraft'

html = Papercraft.html {
  div(id: 'greeter') { p 'Hello!' }
}
```

Rendering a template is done using `#render`:

```ruby
html.render #=> "<div id="greeter"><p>Hello!</p></div>"
```

## All about tags

Tags are added using unqualified method calls, and can be nested using blocks:

```ruby
Papercraft.html {
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
Papercraft.html { p 'hello' }.render #=> "<p>hello</p>"

Papercraft.html { p { span '1'; span '2' } }.render #=> "<p><span>1</span><span>2</span></p>"

Papercraft.html { hr() }.render #=> "<hr/>"
```

Tag methods also accept tag attributes, given as a hash:

```ruby
Papercraft.html { img src: '/my.gif' }.render #=> "<img src="/my.gif"/>

Papercraft.html { p "foobar", class: 'important' }.render #=> "<p class=\"important\">foobar</p>"
```

## Template parameters

In Papercraft, parameters are always passed explicitly. This means that template
parameters are specified as block parameters, and are passed to the template on
rendering:

```ruby
greeting = Papercraft.html { |name| h1 "Hello, #{name}!" }
greeting.render('world') #=> "<h1>Hello, world!</h1>"
```

Templates can also accept named parameters:

```ruby
greeting = Papercraft.html { |name:| h1 "Hello, #{name}!" }
greeting.render(name: 'world') #=> "<h1>Hello, world!</h1>"
```

## Logic in templates

Since Papercraft templates are just a bunch of Ruby, you can easily write your
view logic right in the template:

```ruby
Papercraft.html { |user = nil|
  if user
    span "Hello, #{user.name}!"
  else
    span "Hello, guest!"
  end
}
```

## Template blocks

Templates can also accept and render blocks by using `emit_yield`:

```ruby
page = Papercraft.html {
  html {
    body { emit_yield }
  }
}

# we pass the inner HTML
page.render { h1 'hi' }
```

## Plain procs as components

With Papercraft you can write a template as a plain Ruby proc, and later render
it by passing it as a block to `H`:

```ruby
greeting = proc { |name| h1 "Hello, #{name}!" }
Papercraft.html(&greeting).render('world')
```

Components can also be expressed using lambda notation:

```ruby
greeting = ->(name) { h1 "Hello, #{name}!" }
Papercraft.html(&greeting).render('world')
```

## Component composition

Papercraft makes it easy to compose multiple components into a whole HTML
document. A Papercraft component can contain other components, as the following
example shows.

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

page = Papercraft.html { |title, items|
  html5 {
    head { Title(title) }
    body { ItemList(items) }
  }
}

page.render('Hello from components', [
  { id: 1, text: 'foo', checked: false },
  { id: 2, text: 'bar', checked: true }
])
```

In addition to using components defined as constants, you can also use
non-constant components by invoking the `#emit` method:

```ruby
greeting = -> { span "Hello, world" }

Papercraft.html {
  div {
    emit greeting
  }
}
```

## Parameter and block application

Parameters and blocks can be applied to a template without it being rendered, by
using `#apply`. This mechanism is what allows component composition and the
creation of higher-order components.

The `#apply` method returns a new component which applies the given parameters and
or block to the original component:

```ruby
# parameter application
hello = Papercraft.html { |name| h1 "Hello, #{name}!" }
hello_world = hello.apply('world')
hello_world.render #=> "<h1>Hello, world!</h1>"

# block application
div_wrap = Papercraft.html { div { emit_yield } }
wrapped_h1 = div_wrap.apply { h1 'hi' }
wrapped_h1.render #=> "<div><h1>hi</h1></div>"

# wrap a component
wrapped_hello_world = div_wrap.apply(&hello_world)
wrapped_hello_world.render #=> "<div><h1>Hello, world!</h1></div>"
```

## Higher-order components

Papercraft also lets you create higher-order components (HOCs), that is,
components that take other components as parameters, or as blocks. Higher-order
components are handy for creating layouts, wrapping components in arbitrary
markup, enhancing components or injecting component parameters.

Here is a HOC that takes a component as parameter:

```ruby
div_wrap = Papercraft.html { |inner| div { emit inner } }
greeter = Papercraft.html { h1 'hi' }
wrapped_greeter = div_wrap.apply(greeter)
wrapped_greeter.render #=> "<div><h1>hi</h1></div>"
```

The inner component can also be passed as a block, as shown above:

```ruby
div_wrap = Papercraft.html { div { emit_yield } }
wrapped_greeter = div_wrap.apply { h1 'hi' }
wrapped_greeter.render #=> "<div><h1>hi</h1></div>"
```

## Layout template composition

One of the principal uses of higher-order components is the creation of nested
layouts. Suppose we have a website with a number of different layouts, and we'd
like to avoid having to repeat the same code in the different layouts. We can do
this by creating a `default` page template that takes a block, then use `#apply`
to create the other templates:

```ruby
default_layout = Papercraft.html { |**params|
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

## Emitting raw HTML

Raw HTML can be emitted using `#emit`:

```ruby
wrapped = Papercraft.html { |html| div { emit html } }
wrapped.render("<h1>hi</h1>") #=> "<div><h1>hi</h1></div>"
```

## Emitting a string with HTML Encoding

To emit a string with proper HTML encoding, without wrapping it in an HTML
element, use `#text`:

```ruby
Papercraft.html { str 'hi&lo' }.render #=> "hi&amp;lo"
```

## Emitting Markdown

Markdown is rendered using the
[Kramdown](https://kramdown.gettalong.org/index.html) gem. To emit Markdown, use
`#emit_markdown`:

```ruby
template = Papercraft.html { |md| div { emit_markdown md } }
template.render("Here's some *Markdown*") #=> "<div><p>Here's some <em>Markdown</em><p>\n</div>"
```

[Kramdown
options](https://kramdown.gettalong.org/options.html#available-options) can be
specified by adding them to the `#emit_markdown` call:

```ruby
template = Papercraft.html { |md| div { emit_markdown md, auto_ids: false } }
template.render("# title") #=> "<div><h1>title</h1></div>"
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
`Papercraft::HTML.kramdown_options`, e.g.:

```ruby
Papercraft::HTML.kramdown_options[:auto_ids] = false
```

## Deferred evaluation

Deferred evaluation allows deferring the rendering of parts of a template until
the last moment, thus allowing an inner component to manipulate the state of the
outer component. To in order to defer a part of a template, use `#defer`, and
include any markup in the provided block. This technique, in in conjunction with
holding state in instance variables, is an alternative to passing parameters,
which can be limiting in some situations.

A few use cases for deferred evaulation come to mind:

- Setting the page title.
- Adding a flash message to a page.
- Using components that dynamically add static dependencies (JS and CSS) to the
  page.

The last use case is particularly interesting. Imagine a `DependencyMananger`
class that can collect JS and CSS dependencies from the different components
integrated into the page, and adds them to the page's `<head>` element:

```ruby
default_layout = Papercraft.html { |**args|
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

## Papercraft extensions

Papercraft extensions are modules that contain one or more methods that can be
used to render complex HTML components. Extension modules can be used by
installing them as a namespaced extension using `Papercraft::extension`.
Extensions are particularly useful when you work with CSS frameworks such as
[Bootstrap](https://getbootstrap.com/), [Tailwind](https://tailwindui.com/) or
[Primer](https://primer.style/).

For example, to create a Bootstrap card component, the following HTML markup is
needed (example taken from the [Bootstrap
docs](https://getbootstrap.com/docs/5.1/components/card/#titles-text-and-links)):

```html
<div class="card" style="width: 18rem;">
  <div class="card-body">
    <h5 class="card-title">Card title</h5>
    <h6 class="card-subtitle mb-2 text-muted">Card subtitle</h6>
    <p class="card-text">Some quick example text to build on the card title and make up the bulk of the card's content.</p>
    <a href="#" class="card-link">Card link</a>
    <a href="#" class="card-link">Another link</a>
  </div>
</div>
```

With Papercraft, we could create a `Bootstrap` extension with a `#card` method
and other associated methods:

```ruby
module BootstrapComponents
  ...

  def card(**props)
    div(class: 'card', **props) {
      div(class: 'card-body') {
        emit_yield
      }
    }
  end

  def card_title(title)
    h5 title, class: 'card-title'
  end

  ...
end

Papercraft.extension(bootstrap: BootstrapComponents)
```

The call to `Papercraft::extension` lets us access the different methods of
`BootstrapComponents` by calling `#bootstrap` inside a template. With this,
we'll be able to express the above markup as follows:

```ruby
Papercraft.html {
  bootstrap.card(style: 'width: 18rem') {
    bootstrap.card_title 'Card title'
    bootstrap.card_subtitle 'Card subtitle'
    bootstrap.card_text 'Some quick example text to build on the card title and make up the bulk of the card''s content.'
    bootstrap.card_link '#', 'Card link'
    bootstrap.card_link '#', 'Another link'
  }
}
```

## JSON templating

You can create a JSON template using the same API used for HTML and XML
templating. The only difference is that for adding array items you'll need to
use the `#item` method:

```ruby
Papercraft.json {
  item 1
  item 2
  item 3
}.render #=> "[1,2,3]"
```

Otherwise, you can create arbitrarily complex JSON structures by mixing hashes
and arrays:

```Ruby
Papercraft.json {
  foo {
    bar {
      item nil
      item true
      item 123.456
    }
  }
}.render #=> "{\"foo\":{\"bar\":[null,true,123.456]}}"
```

Papercraft uses the [JSON gem](https://rubyapi.org/3.1/o/json) under the hood.

## API Reference

The API reference for this library can be found
[here](https://www.rubydoc.info/gems/papercraft).