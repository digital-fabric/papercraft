pr1 = -> { p 'foo' }
pr2 = ->(x) { p x }

->() {
  render pr1
  br
  render pr2, 42
}
