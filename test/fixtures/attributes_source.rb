o = Object.new
def o.fuzz
  'fuzz'
end

->() {
  br
  h1('title', id: 'main-title')
  div(class: 'section') {
    h2 'foo'
  }
  h3 'bar', id: 'baz', class: o.fuzz

  h4 'Hi', data_ref: '42'

  attrs = { class: 'klass', data_foo: 'bar' }
  h5 'Bye', **attrs
}
