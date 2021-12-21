require 'bundler/setup'
require 'papercraft'

App = H {
  html5 {
    head {
      stylesheet '/assets/style.css', media: 'screen'
      favicon '/favicon.ico'
      link href: "https://fonts.gstatic.com", rel: "preconnect", crossorigin: true
    }
  }
}

class Rubyoshka::Rendering
  def stylesheet(path, **attributes)
    link({
      rel: 'stylesheet',
      href: path,
    }.merge(attributes))
  end

  def favicon(path)
    link(
      rel: 'favicon',
      href: path
    )
  end
end

puts App.render
