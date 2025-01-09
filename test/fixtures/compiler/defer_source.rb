->() {
  div {
    defer {
      h1 @foo
    }
    @foo = 'bar'
  }
}
