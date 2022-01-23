require 'bundler/setup'
require 'papercraft'

App = Papercraft.html {
  html5 {
    body {
      Header(title: 'My app') {
        button "1"
        button "2"
      }
      Content {}
    }
  }
}

Header = ->(title:, &children) {
  Papercraft.html {
    header {
      h2(title, id: 'title')
      emit children
    }
  }
}

Content = Papercraft.html {
  article {
    h3 context[:title]
    p "Hello, world!"
    div {
      a(href: 'http://google.com/?a=1&b=2&c=3 4') { h3 "foo bar" }
      p "lorem ipsum "
    }
  }
}

puts App.render(title: 'title from context')