## Performance improvements

See https://github.com/digital-fabric/p2/pull/1#issuecomment-3165405341

- [v] Add `# frozen_string_literal: true` at the top of eval
- [v] coalesce static strings only. emit interpolated strings separately
- [ ] Replace emit calls with direct invocation

      ```ruby
      # currently
      __buffer__ << P2.render_emit_call(Header, title: title, &(->(__buffer__) {
          ; __buffer__ << "<button>1</button><button>2</button>"
        }.compiled!))
      __buffer__ << P2.render_emit_call(Content, title: title)

      # direct invocation
      Header.compiled_proc.(__buffer__, title: title, &(->(__buffer__) {
        ; __buffer__ << "<button>1</button><button>2</button>"
      }).compiled!)
      Content.compiled_proc.(__buffer__, title: title)
      ```

      In order to be able to do this, we need to fine-tune the API a bit:

      - `emit` is for emitting a partial, or sub-template, i.e. a proc
      - in order to emit raw html, we need a separate API: `raw`

      So plan of action:

      - Introduce `raw`, switch to it in all relevant tests

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
