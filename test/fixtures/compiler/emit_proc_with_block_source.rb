# frozen_string_literal: true
pr = ->(id) { foo(id: id) { emit_yield } }

->() {
  emit(pr, 'x42') {
    bar 'baz'
  }
}
