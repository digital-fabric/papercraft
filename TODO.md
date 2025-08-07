- [ ] Add support for `emit ->(x) { p x }, 

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
        ulist: ->(list, item_proc) {
          ul {
            list.each { emit item_proc, it }
          }
        }
      )
      ```
