require 'bundler/setup'
require 'papercraft'
require 'time'

content = {
  articles: [
    { title: 'Foo', link: 'http://blog.site/articles/1', stamp: Time.now - rand(86400 * 1000), description: 'Bar' },
    { title: 'Baz', link: 'http://blog.site/articles/2', stamp: Time.now - rand(86400 * 1000), description: 'Blah' },
  ]
}

RSSItem = Papercraft.xml { |item|
  item {
    title item[:title]
    link item[:link]
    pubDate item[:stamp].httpdate
    description item[:description]
  }
}

RSS = Papercraft.xml { |articles:|
  rss(version: '2.0') {
    channel {
      title 'Liftoff News'
      link 'http://liftoff.msfc.nasa.gov/'
      description 'Liftoff to Space Exploration.'
      language 'en-us'
      pubDate Time.now.httpdate
      articles.each { |a|
        emit RSSItem, a
      }
    }
  }
}

puts RSS.render(**content)