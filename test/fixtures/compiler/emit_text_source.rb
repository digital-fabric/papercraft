x = 'bar&baz'

->() {
  emit 'foo&bar'
  br
  emit x
}
