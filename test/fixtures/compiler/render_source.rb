pr1 = -> { p 'foo' }
pr2 = ->(x) { p x }

->() {
  render pr1
  render pr2, 42
  br
  render -> { q 'bar' }
}
