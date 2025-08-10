## API

- [ ] Fluent interface with ids and classes and other utilities:

      ```ruby
      p[:my_id].foo 'bar' #=> <p id="my-id" class="foo">bar</p>"
      article.data(
        columns: 3,
        index_number: 12314
      ) #=> <article data-columns="3" data-index-number="12314"></article>
      ```

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

      - [ ] Reimplement source map generation such that it can include entries
            pointing to different files

            ```ruby

            ```

- [ ] Extensions expressed as procs:

      ```ruby
      P2.extension(
        html: -> {
          emit('<!DOCTYPE html>')
          tag(:html) { emit_yield }
        },
        markdown: ->(md) {
          emit P2.markdown(md)
        },
        ulist: ->(list, item_proc) {
          ul {
            list.each { emit item_proc, it }
          }
        }
      )
      ```

