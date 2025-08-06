## Reimplementation

- [v] No template class, everything is just procs
- [v] Always compiled before running
- [v] Nested templates (i.e. procs) are also compiled
- [ ] Generate source maps and translate backtraces
- [ ] Fluent interface with ids and classes and other utilities:

      ```ruby
      p[:my_id].foo 'bar' #=> <p id="my-id" class="foo">bar</p>"
      article.data(
        columns: 3,
        index_number: 12314
      ) #=> <article data-columns="3" data-index-number="12314"></article>
      ```

- [ ] Extensions expressed as procs:

      ```ruby
      P2.extension(
        html: -> {
          emit('<!DOCTYPE html>')
          tag(:html) { yield }
        },
        markdown: ->(md) {
          emit P2.markdown(md)
        },
        
      )
      ```

      Can extension templates be inlined? What would prevent a template from
      being inlined?
    
      - Variable assignment
      - Return statements
      - Rescue clauses

## Enhancements

- [ ] Automatic compilation
- [ ] Once everything's compiled, add support for following:

      ```ruby
      P2.html {
        # class
        p.my_class 'foo' #=> <p class="my-class">foo</p>

        # or maybe
        p.class('my-class') 'foo'

        # or maybe
        p(class: 'my-class') 'foo'

        # or maybe
        p(class: 'my-class') { 'foo' }

        # id
        p['my-id'] 'foo' #=> <p id="my-id">foo</p>
      }
      ```

