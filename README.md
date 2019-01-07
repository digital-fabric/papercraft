# Rubyoshka - Composable HTML templating for Ruby

[INSTALL](#installing-rubyoshka) |
[TUTORIAL](#getting-started) |
[EXAMPLES](examples) |
[REFERENCE](#api-reference)

## What is Rubyoshka

Rubyoshka is an HTML templating engine for Ruby that offers the following
features:

- HTML templating using plain Ruby syntax
- Minimal boilerplate
- Mix logic and tags freely
- Use global and local contexts to pass values to reusable components
- Automatic HTML escaping
- Composable nested components
- About 4 times faster than ERubis (see [benchmark](examples/perf.rb)).

> **Note** Rubyoshka is a new library and as such may be missing features and
> contain bugs. Your issue reports and code conributions are most welcome!

With Rubyoshka you can structure your templates like a Russian doll, each
component containing any number of nested components, in a somewhat similar
fashion to React. The name *Rubyoshka* is a nod to Matryoshka, the Russian
nesting doll.

## Installing Rubyoshka

```bash
$ gem install polyphony
```

## Getting started

To use Rubyoshka in your code just require it:

```ruby
require 'rubyoshka'
```

Alternatively, you can import it using [Modulation](https://github.com/digital-fabric/modulation):

```ruby
Rubyoshka = import('rubyoshka')
```

To create a template use `Rubyoshka.new` or the global method `Kernel#H`:

```ruby
# can also use Rubyoshka.new
html = H {
  div { p 'hello' }
}
```

## Rendering a template

To render a Rubyoshka template use the `#render` method:

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

## Logic in templates

Since Rubyoshka templates are just a bunch of Ruby, you can easily write your
view logic right in the template:

```ruby
def user_message(user)
  H {
    if user
      span "Hello, #{user.name}!"
    else
      span "Hello, guest!"
    end
  }
end
```

## Local context

When writing logic and referring to application values in you templates, there
are some ground rules to obey. Since the template code is evaluated using
`#instance_eval` that means that you will not be able to directly use instance
variables or do unqualified method calls (calls to `self`).

In order to facilitate exposing values to your template logic, Rubyoshka
provides an API for setting a local context. The local context is simply a set
of values that are accessible for a given block of code, and to any nested
blocks within it. The local context is primarily set using the `#with` method:

```ruby
H {
  with(name: 'world') {
    div {
      span "Hello, #{name}"
    }
  }
}
```

The local context can alternatively be set by passing hash values to `#H`:

```ruby
H(name: 'world') {
  div { span "Hello, #{name}" }
}
```

A local context can also be set for a component (see the next section) simply by
passing arguments to the component call:

```ruby
Greeting = H { span "Hello, #{name}" }

H {
  div {
    Greeting(name: 'world')
  }
}
```

### Tip: accessing `self` and instance variables from a template

In order to be able to access the object in the context of which the template is
defined or any of its methods, you can pass it in the local context:

```ruby
class User
  ...
  def greeting_template
    H(user: self) {
      ...
      span "Hello, #{user.name}"
      span "your email: #{user.email}"
    }
  end
end
```

Instance variables can be passed to the template in a similar fashion:

```ruby
H(name: @name) { span "Hello, #{name}" }
```

## Global context

In addition to the local context, Rubyoshka also provides a way to set a global
context, accessible from anywhere in the template, and also in sub-components 
used in the template.

The global context is a simple hash that can be accessed from within the
template with the `#context` method:

```ruby
greeting = H { span "Hello, #{context[:name]}" }
```

The global context can be set upon rendering the template:

```ruby
greeting.render(name: 'world')
```

## Templates as components

Rubyoshka makes it easy to compose multiple separate templates into a whole HTML
document. Each template can be defined as a self-contained component that can
be reused inside other components. Components should be defined as constants,
either in the global namespace, or on the `Rubyoshka` namespace. Each component
can be defined as either a Rubyoshka instance (using `#H`) or as a `proc` that
returns a Rubyoshka instance:

```ruby
Title = H { h1 title }

# Item is actually a Proc that returns a template
Item = ->(id:, text:, checked:) {
  H {
    li {
      input name: id, type: 'checkbox', checked: checked
      label text, for: id
    }
  }
}

def render_items(items)
  html = H {
    Title()
    ul {
      items.each { |id, attributes|
        Item id: id, text: attributes[:text], checked: attributes[:active]
      }
    }
  }.render
end
```

Note that a component is invoked as a method, which means that if no arguments
are passed, you should add an empty pair of parens, as shown in the example
above.

In addition to using components defined as constants, you can also use
non-constant components by invoking the `#emit` method:

```ruby
greeting = H { span "Hello, world" }

H {
  div {
    emit greeting
  }
}
```

## Wrapping arbitrary HTML with a component

Components can also be used to wrap arbitrary HTML with addional markup. This is
done by implementing the component as a `proc` that takes a block:

```ruby
Header = ->(&inner_html) {
  header {
    h1 'This is a title'
    emit inner_html
  }
}

Greeting = H { span "Hello, #{name}" }

H { Header { Greeting(name: 'world') }.render #=> "<header><h1>This is a title</h1><span>Hello, world</span></header>"
```

## Some interesting use cases

Rubyoshka opens up all kinds of new possibilities when it comes to putting
together pieces of HTML. Feel free to explore the API!

### Routing in the view

The following example demonstrates a router component implemented as a pure
function. The router simply returns the correct component for the given path:

```ruby
Router = ->(path) {
  case path
  when '/'
    PostIndex()
  when /^posts\/(.+)$/
    Post(get_post($1))
  end
}

Blog = H {
  html {
    head {
      title: 'My blog'
    }
    body {
      Topbar()
      Sidebar()
      div id: 'content' { Router(context[:path]) }
    }
  }
}
```

### A general purpose router

A more flexible, reusable approach could be achieved by implementing a
higher-order routing component, in a similar fashion to
[React Router](https://reacttraining.com/react-router/web/guides/quick-start):

```ruby
Route = ->(path, &block) {
  match = path.is_a?(Regexp) ?
    context[:path] =~ path : context[:path] == /^#{path}/
  emit block if match
}

Blog = H {
  html {
    head {
      title: 'My blog'
    }
    body {
      Topbar()
      Sidebar()
      div id: 'content' {
        Route '/'             { PostIndex() }
        Route /^posts\/(.+)$/ { Post(get_post($1)) }
      }
    }
  }
}
```

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

#### `Rubyoshka#initialize(**context, &block)` a.k.a. `Kernel#H`

- `context`: local context hash
- `block`: template block

Initializes a new Rubyoshka instance. This method takes a block of template 
code, and an optional [local context](#local-context) in the form of a hash.
The `Kernel#H` method serves as a shortcut for creating Rubyoshka instances.

#### `Rubyoshka#render(**context)`

- `context`: global context hash

Renders the template with an optional [global context](#global-context)
hash.

#### Methods accessible inside template blocks

#### `#<tag/component>(*args, **props, &block)`

- `args`: tag arguments. For an HTML tag Rubyoshka expects a single `String`
  argument containing the inner text of the tag.
- `props`: hash of tag attributes
- `block`: inner HTML block

Adds a tag or component to the current template. If the method name starts with
an upper-case letter, it is considered a [component](#templates-as-components).

If a text argument is given for a tag, it will be escaped.

#### `#context`

Accesses the [global context](#global-context).

#### `#emit(object)` a.k.a. `#e(object)`

- `object`: `Proc`, `Rubyoshka` instance or `String`

Adds the given object to the current template. If a `String` is given, it is
rendered verbatim, i.e. without escaping.

#### `html5(&block)`

- `block`: inner HTML block

Adds an HTML5 `doctype` tag, followed by an `html` tag with the given block.

#### `#text(data)`

- `data` - text to add

Adds text without wrapping it in a tag. The text will be escaped.

#### `#with(**context, &block)`

- `context`: local context hash
- `block`: HTML block

Sets a [local context](#local-context) for use inside the given block. The
previous local context will be restored upon exiting the given block.
