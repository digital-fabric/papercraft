->() {
  div {
    defer {
      h1 @foo
    }
    h2 'baz'
    @foo = 'bar'
  }
}
