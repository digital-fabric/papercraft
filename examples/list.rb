require 'bundler'
require 'papercraft'

List = ->(items, item_component) {
  Papercraft.html {
    ul {
      items.each { |item|
        with(item: item) {
          li { emit item_component }
        }
      }
    }
  }
}

TodoItem = Papercraft.html {
  span item[:text], class: item[:completed] ? 'done' : 'pending'
}

def todo_list(items)
  Papercraft.html {
    div {
      List(items, TodoItem)
    }
  }
end

puts todo_list([
  { completed: false, text: 'Buy milk' },
  { completed: false, text: 'Take out trash' },
  { completed: true,  text: 'Use Rubyoshka' }
]).render