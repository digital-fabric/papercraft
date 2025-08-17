# frozen_string_literal: true
pr = ->(id) { foo(id: id) { render_yield } }

->() {
  render(pr, 'x42') {
    bar 'baz'
  }
}
