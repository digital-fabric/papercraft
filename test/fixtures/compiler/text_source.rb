x = 'bar&baz'

->() {
  h1 {
    text 'foo&bar'
  }
  text # should emit nothing
  h2 {
    text x
  }
}
