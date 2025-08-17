require 'bundler/setup'
require 'p2'

App = ->(**props) {
  html5 {
    body {
      emit(Header, title: props[:title]) {
        button "1"
        button "2"
      }
      emit Content, **props
    }
  }
}

Header = ->(title:) {
  header {
    h2(title, id: 'title')
    render_yield
  }
}

Content = ->(title:) {
  article {
    h3 title
    p "Hello, world!"
    div {
      a(href: 'http://google.com/?a=1&b=2&c=3 4') { h3 "foo bar" }
      p "lorem ipsum "
    }
  }
}

puts App.render(title: 'title parameter')
