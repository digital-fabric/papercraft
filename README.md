# Papercraft - Composable HTML templating for Ruby

[INSTALL](#installing-papercraft) |
[TUTORIAL](#getting-started) |
[EXAMPLES](examples) |
[REFERENCE](#api-reference)

## What is Papercraft?

Papercraft is an HTML templating engine for Ruby that offers the following
features:

- HTML templating using plain Ruby syntax
- Minimal boilerplate
- Mix logic and tags freely
- Use global and local contexts to pass values to reusable components
- Automatic HTML escaping
- Composable components
- Higher order components
- Built-in support for rendering Markdown

> **Note** Papercraft is a new library and as such may be missing features and
> contain bugs. Also, its API may change unexpectedly. Your issue reports and
> code contributions are most welcome!

With Papercraft you can structure your templates as nested HTML components, in a
somewhat similar fashion to React.

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

To use Papercraft in your code just require it:

```ruby
require 'papercraft'
```

To create a template use `Papercraft.new` or the global method `Kernel#H`:

```ruby
# can also use Papercraft.new
html = H {
  div { p 'hello' }
}
```

## Rendering a template

To render a Papercraft template use the `#render` method:

```ruby
H { span 'best span' }.render  #=> "<span>best span</span>"
```

The render method accepts an arbitrary context variable:

```ruby
html = H {
  h1 context[:title]
}

html.render(title: 'My title') #=> "<h1>My title</h1>"
```

## All about tags

Tags are added using unqualified method calls, and are nested using blocks:

```ruby
H {
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
H { p 'hello' }.render #=> "<p>hello</p>"

H { p { span '1'; span '2' } }.render #=> "<p><span>1</span><span>2</span></p>"

H { hr() }.render #=> "<hr/>"
```

Tag methods also accept tag attributes, given as a hash:

```ruby
H { img src: '/my.gif' }.render #=> "<img src="/my.gif"/>

H { p "foobar", class: 'important' }.render #=> "<p class=\"important\">foobar</p>"
```

## Template parameters

Template parameters are specified as block parameters, and are passed to the
template on rendering:

```ruby
greeting = H { |name| h1 "Hello, #{name}!" }
greeting.render('world') #=> "<h1>Hello, world!</h1>"
```

Templates can also accept named parameters:

```ruby
greeting = H { |name:| h1 "Hello, #{name}!" }
greeting.render(name: 'world') #=> "<h1>Hello, world!</h1>"
```

## Logic in templates

Since Papercraft templates are just a bunch of Ruby, you can easily write your
view logic right in the template:

```ruby
H { |user = nil|
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
page = H {
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
H(&greeting).render('world')
```

Components can also be expressed using lambda notation:

```ruby
greeting = ->(name) { h1 "Hello, #{name}!" }
H(&greeting).render('world')
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

page = H { |title, items|
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

H {
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
hello = H { |name| h1 "Hello, #{name}!" }
hello_world = hello.apply('world')
hello_world.render #=> "<h1>Hello, world!</h1>"

# block application
div_wrap = H { div { emit_yield } }
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
div_wrap = H { |inner| div { emit inner } }
greeter = H { h1 'hi' }
wrapped_greeter = div_wrap.apply(greeter)
wrapped_greeter.render #=> "<div><h1>hi</h1></div>"
```

The inner component can also be passed as a block, as shown above:

```ruby
div_wrap = H { div { emit_yield } }
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
default_layout = H { |**params|
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
wrapped = H { |html| div { emit html } }
wrapped.render("<h1>hi</h1>") #=> "<div><h1>hi</h1></div>"
```

## Emitting a string with HTML Encoding

To emit a string with proper HTML encoding, without wrapping it in an HTML
element, use `#text`:

```ruby
H { str 'hi&lo' }.render #=> "hi&amp;lo"
```

## Emitting Markdown

To emit Markdown, use `#emit_markdown`:

```ruby
template = H { |md| div { emit_markdown md } }
template.render("Here's some *Markdown*") #=> "<div>Here's some <em>Markdown</em></div>"
```

## Some interesting use cases

Papercraft opens up all kinds of new possibilities when it comes to putting
together pieces of HTML. Feel free to explore the API!

### A higher-order list component

Here's another demonstration of a higher-order component, a list component that
takes an item component as an argument. The `List` component can be reused for
rendering any kind of unordered list, and with any kind of item component:

```ruby
List = ->(items, item_component) {
  H {
    ul {
      items.each { |item|
        with(item: item) {
          li { emit item_component }
        }
      }
    }
  }
}

TodoItem = H {
  span item.text, class: item.completed ? 'completed' : 'pending'
}

def todo_list(items)
  H {
    div { List(items, TodoItem) }
  }
end
```

## API Reference

#### `Papercraft#initialize(**context, &block)` a.k.a. `Kernel#H`

- `context`: local context hash
- `block`: template block

Initializes a new Papercraft instance. This method takes a block of template
code, and an optional [local context](#local-context) in the form of a hash.
The `Kernel#H` method serves as a shortcut for creating Papercraft instances.

#### `Papercraft#render(**context)`

- `context`: global context hash

Renders the template with an optional [global context](#global-context)
hash.

#### Methods accessible inside template blocks

#### `#<tag/component>(*args, **props, &block)`

- `args`: tag arguments. For an HTML tag Papercraft expects a single `String`
  argument containing the inner text of the tag.
- `props`: hash of tag attributes
- `block`: inner HTML block

Adds a tag or component to the current template. If the method name starts with
an upper-case letter, it is considered a [component](#templates-as-components).

If a text argument is given for a tag, it will be escaped.

#### `#cache(*vary, &block)`

- `vary`: variables used in cached block. The given values will be used to
  create a separate cache entry.
- `block`: inner HTML block

Caches the markup in the given block, storing it in the Papercraft cache store.
If a cache entry for the given block is found, it will be used instead of
invoking the block. If one or more variables given, those will be used to create
a separate cache entry.

#### `#context`

Accesses the [global context](#global-context).

#### `#emit(object)` a.k.a. `#e(object)`

- `object`: `Proc`, `Papercraft` instance or `String`

Adds the given object to the current template. If a `String` is given, it is
rendered verbatim, i.e. without escaping.

#### `html5(&block)`

- `block`: inner HTML block

Adds an HTML5 `doctype` tag, followed by an `html` tag with the given block.

#### `#text(data)`

- `data` - text to add

Adds text without wrapping it in a tag. The text will be escaped.
