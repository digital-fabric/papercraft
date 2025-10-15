## Existing

```ruby
layout = ->(**) {
  html {
    body {
      render_children(**)
    }
  }
}

page = layout.apply { |title:, **|
  h1 title
}

page.render(title: 'foo')
```

## Alternative

```ruby
layout = ->(**) {
  html {
    body {
      render_children(**)
    }
  }
}

page = Papercraft.apply(layout) { |title:, **|
  h1 title
}

Papercraft.render(page, title: 'foo')
```

## Papercraft landing page example

```ruby
Papercraft.render(
  -> {
    h1 "Hello from Papercraft!"
  }
)
#=> "<h1>Hello from Papercraft!</h1>"
```

## API

- [ ] Support for inlining (needed for doing extension procs - see below)

  - [ ] Detect procs that can be inlined by interrogating the original
        proc's binding:

        ```ruby
        # for local variable:
        o.binding.local_variable_defined?(:foo)
        o.binding.local_variable_get(:foo)

        # for const
        o.binding.eval('Foo')
        ```

  - [ ] Detect whether proc can be inlined:

    - No local var assignments
    - No return statements

