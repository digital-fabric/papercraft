require 'bundler/setup'
require 'papercraft'

Title = ->(title) { h1 title }

Item = ->(id:, text:, checked:) {
  li {
    input name: id, type: 'checkbox', checked: checked
    label text, for: id
  }
}

ItemList = ->(items) {
  ul {
    items.each { |i|
      Item(**i)
    }
  }
}

page = ->(title, items) {
  html5 {
    head { Title(title) }
    body { ItemList(items) }
  }
}

puts page.render('Hello from composed templates', [
  { id: 1, text: 'foo', checked: false },
  { id: 2, text: 'bar', checked: true }
])
