## Performance improvements

See https://github.com/digital-fabric/p2/pull/1#issuecomment-3165405341

- [v] Add `# frozen_string_literal: true` at the top of eval
- [v] coalesce static strings only. emit interpolated strings separately
- [v] Replace emit calls with direct invocation

- [ ] Allow more compact API for composing templates:

      ```ruby
      App = -> {
        html {
          body {
            # instead of render Header, title: 'foo'
            Header(title: 'foo')
            Content()
          }
        }
      }

      Header = ->(title:) {
        header {
          h1 title
          button 'click me'
        }
      }

      Content = -> {
        div(class: 'content') {
          p 'Lorem ipsum'
        }
      }
      ```

      In fact, 



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
