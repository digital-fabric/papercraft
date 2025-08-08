# frozen_string_literal: true
pr = ->(id) { foo(id: id) { emit_yield } }

->() {
  render(pr, 'x42') {
    bar 'baz'
  }
}
