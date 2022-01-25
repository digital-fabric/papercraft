require 'bundler/setup'
require 'papercraft'

module CustomHTML
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

Papercraft.extension(custom: CustomHTML)

page = Papercraft.html {
  html5 {
    head {
      custom.stylesheet '/assets/style.css', media: 'screen'
      custom.favicon '/favicon.ico'
    }
  }
}

puts page.render
