## Immediate

## Switch code generation to generating a method

Benchmarks show a significant performance increase when instead of creating a
compiled lambda, we create a method that is invoked directly. Take the following
example:

```ruby
t = ->(foo, bar) {
  div {
    h1 foo
    h2 bar
  }
}
```

The compiled form currently is:

```ruby
->(__buffer__, foo, bar) {
  __buffer__
    .<<("<div><h1>")
    .<<(ERB::Escape.html_escape((foo)))
    .<<("</h1><h2>")
    .<<(ERB::Escape.html_escape((bar)))
    .<<("</h2></div>")
  __buffer__
}
```

Instead, we can define a method on the template itself:

```ruby
def t.__papercraft_render_html(__buffer__, foo, bar)
  __buffer__
    .<<("<div><h1>")
    .<<(ERB::Escape.html_escape((foo)))
    .<<("</h1><h2>")
    .<<(ERB::Escape.html_escape((bar)))
    .<<("</h2></div>")
  __buffer__
end
```

And then, we change `Papercraft.html` to do:

```ruby
def Papercraft.html(template, *, **, &)
  template.__papercraft_render_html(+'', *, **, &)
rescue => e
  translate_backtrace(e)
end
```

The default impl for `__papercraft_render_html` can be:

```ruby
class ::Proc
  def __papercraft_render_html(*, **, &)
    Papercraft.compile_render_html_method(self)
    __papercraft_render_html(*, **, &)
  end
end
```

## Support for inlining

### Uses

- components: `render Table, ...`
- extensions: `foo_thing ...`
- applied blocks: `render_yield ...`

### Challenges

- Whitespace: should be able to preserve whitespace, but the inlined code
  should be kept on separate lines, i.e. leading and trailing `\n`.
- Sourcemaps: generate sourcemap entries pointing to original code of
  inlined proc.
- Recursive inlining: Inlining should be recursive, such that inlined procs
  should themselves go through the process of inlining. This also means that
  the property of whether a proc can be inlined is also recursive. It can
  only be inlined if its consitutent sub-templates are also inlineable.

- Detect procs that can be inlined by interrogating the original proc's binding:

```ruby
# for local variable:
o.binding.local_variable_defined?(:foo)
o.binding.local_variable_get(:foo)

# for const
o.binding.eval('Foo')
```

- Detect whether proc can be inlined:

  - No local var assignments (LocalVariableWriteNode)
  - No return/break statements (BreakNode, ReturnNode)
  - No rescue statements (RescueNode)

```ruby
Card = ->(title, text) {
  card {
    h1 title
    p text
  }
}

Content = -> {
  Card(
    "Foobar",
    "Lorem ipsum"
  )
  Card(
    "Barbaz",
    "Schlorem ipsum"
  )
}

#=>:
->(__buffer__) {
  card {
    h1 "Foobar"
    p "Lorem ipsum"
  }
  card {
    h1 "Barbaz"
    p "Schlorem ipsum"
  }
}
```

Actually, the entire thing could be done at the translation phase! When mutating
the tree, we can just take the inlined proc, find its AST, make sure its
inlineable, replace all parameter refs (LocalVariableReadNode) with the applied
parameters, and replace the `render`, `render_yield`, or component method call
with the inlined AST.

### Keeping track of component and block references

Consider the following:

```ruby
HeadLinks = ->(**props) {
  props[:links].each {
    link ...
  }
}

DefaultLayout = ->(**props) {
  html {
    head {
      HeadLinks(**props)
    }
    body {
      render_yield(**props)
    }
  }
}

FancyLayout = Papercraft.apply(DefaultLayout) { |**props|
  article {
    render_yield(**props)
  }
}

SuperFancyLayout = Papercraft.apply(FancyLayout) { |**props|
  h1 'foo'
}
```

In order to apply it into a single compiled lambda, we need to somehow track the
original procs and asts. For each proc, we can track its "dependencies" so to
speak:

- `HeadLinks`: no deps
- `DefaultLayout`: deps: HeadLinks
- `FancyLayout`: deps: FancyLayout
- `SuperFancyLayout`: deps: SuperFancyLayout

### Apply is more difficult for inlining

```ruby
InlinedDefaultLayout = ->(**props) {
  html {
    head {
      # inlined HeadLinks
      props[:links].each {
        link ...
      }
    }
    body {
      render_yield(**props)
    }
  }
}

InlinedFancyLayout = ->(**props) {
  html {
    head {
      # HeadLinks(**props)
      # inlined HeadLinks
      props[:links].each {
        link ...
      }
    }
    body {
      # render_yield(**props)
      # inlined render_yield
      article {
        render_yield(**props)
      }
    }
  }
}

SuperFancyLayout = ->(**props) {
  html {
    head {
      # HeadLinks(**props)
      # inlined HeadLinks
      props[:links].each {
        link ...
      }
    }
    body {
      # render_yield(**props)
      # inlined render_yield
      article {
        h1 'foo'
      }
    }
  }
}

```

So each time we call apply, we need to take the previous step's AST and perform
the inlining. So, that means we need to store the inlined AST in the original
proc, so:

```ruby
# The apply op first compiles DefaultLayout, which generates an inlined AST
# which is then stored in the DefaultLayout object, and then this AST is mutated
# to generate the applied AST - which injects the given block and / or arguments
# into the mutated AST, which is then stored in FancyLayout, and so forth...
FancyLayout = Papercraft.apply(DefaultLayout) { ... } 
```

## Support for introspection

### Objectives

Some of the applications:

- Debugging
  - Be able to find problems with a view, like why something was not rendered,
    or why it was rendered incorrectly.
  - Be able to inspect dependencies
- Testing
  - Be able to test the output of a template, the existence of an element, etc.
- Annotation
  - Be able to annotate specific elements
- Refactoring
  - Tools for extracting parts of templates, or rewriting templates
- Partial rendering
  - Render only parts of a template

### How

One option:

- Use CSS-like selectors to select nodes
- Select tag nodes from AST

Another option (at least for testing):

- Just use Nokigiri and wrap that with some conveient API

### API

```ruby
t = ->(name) {
  body {
    div {
      h1 "Hello, #{name}!"
    }
  }
}

# partial
div = Papercraft.partial(t, "div")
Papercraft.html(div, "world") #=> "<h1>Hello, world!</h1>"

# render partial
html = Papercraft.html_partial(t, "div", "world!")

# get node
node = Papercraft.select(t, "div") #=> TagNode("div")
```
