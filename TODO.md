## Immediate

- [ ] - Fix bad compiled source generation ternary op:

  ```ruby
  -> (p) {
    p ? a('<', href: p, class: 'prev') : span(class: 'prev')
  }
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
