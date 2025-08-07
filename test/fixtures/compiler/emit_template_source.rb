pr1 = -> { p 'foo' }
pr2 = ->(x) { p x }

->() {
  emit pr1
  emit pr2, 42
  br
  emit -> { q 'bar' }
}
