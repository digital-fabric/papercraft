# Rubyoshka - Composable HTML templating for Ruby

[INSTALL](#installing-rubyoshka) |
[TUTORIAL](#getting-started) |
[EXAMPLES](examples)

## What is Rubyoshka

Rubyoshka is an HTML templating engine for Ruby that offers the following
features:

- HTML templating using plain Ruby syntax
- Minimal boilerplate
- Mix logic and tags freely
- Automatic HTML escaping
- Composable nested components
- Access to a global context from anywhere in the component hierarchy
- High performance (see [benchmark](examples)).

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

Since the template code is evaluated using `#instance_eval` in the context of a 
Rubyoshka instance, things may not work as you'd expect. You will not be able to
access instance variables and methods in your own objects, but you _will_ be
able to access local variables and arguments.

If you need to access instance variables, you'll need to copy them to local variables outside of the template block:

```ruby
class User
  def greeting
    name = @name
    H {
      span "Hello, #{name}"
    }
  end
end
```

## Templates as components

Rubyoshka makes it easy to compose multiple templates into a whole HTML
document. Each template can be defined as a self-contained component that can
be reused inside other components. Components should be defined as constants,
either in the global namespace, or on the Rubyoshka namespace:

```ruby
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
    ul {
      items.each { |id, attributes|
        Item id: id, text: attributes[:text], checked: attributes[:active]
      }
    }
  }.render
end
```

## Wrapping arbitrary HTML

Components can be used to wrap arbitrary HTML content by defining them as procs
that accept blocks:

```ruby
Header = ->(&inner_html) {
  header {
    h1 'title'
    emit inner_html
  }
}

H { Header { button 'OK'} }.render #=> "<header><h1>title</h1><button>OK</button></header>"
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