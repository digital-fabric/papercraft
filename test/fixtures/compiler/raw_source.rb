x = 'bar&baz'

->() {
  raw 'foo&bar'
  br
  raw x
}
