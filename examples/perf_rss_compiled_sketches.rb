require 'bundler/setup'
require 'papercraft'
require 'benchmark/ips'
require 'date'
require 'time'
require 'escape_utils'

props = {
  articles: [
    {
      title: 'Foo',
      link: '/articles/foo',
      date: Date.new(2022, 01, 03),
      html_content: '<h1>Hello, foo!</h1>'
    },
    {
      title: 'Bar',
      link: '/articles/bar',
      date: Date.new(2022, 01, 02),
      html_content: '<h1>Hello, bar!</h1>'
    },
    {
      title: 'Baz',
      link: '/articles/baz',
      date: Date.new(2022, 01, 01),
      html_content: '<h1>Hello, baz!</h1>'
    },
    {
      title: 'Foo',
      link: '/articles/foo',
      date: Date.new(2022, 01, 03),
      html_content: '<h1>Hello, foo!</h1>'
    },
    {
      title: 'Bar',
      link: '/articles/bar',
      date: Date.new(2022, 01, 02),
      html_content: '<h1>Hello, bar!</h1>'
    },
    {
      title: 'Baz',
      link: '/articles/baz',
      date: Date.new(2022, 01, 01),
      html_content: '<h1>Hello, baz!</h1>'
    },

  ]
}

tmpl1 = Papercraft.xml(mime_type: 'text/xml; charset=utf-8') { |articles:|
  rss(version: '2.0', 'xmlns:atom' => 'http://www.w3.org/2005/Atom') {
    channel {
      title 'Noteflakes'
      link 'https://noteflakes.com/'
      description 'A website by Sharon Rosner'
      language 'en-us'
      pubDate Time.now.httpdate
      emit '<atom:link href="https://noteflakes.com/feeds/rss" rel="self" type="application/rss+xml" />'

      article_entries = articles.reverse
      article_entries.each { |e|
        item {
          title e[:title]
          link "https://noteflakes.com#{e[:url]}"
          guid "https://noteflakes.com#{e[:url]}"
          pubDate e[:date].to_time.httpdate
          description e[:html_content]
        }
      }
    }
  }
}

tmpl2 = ->(articles:) {
  buffer = +''
  buffer << "<rss version=\"2.0\" xmlns:atom=\"http://www.w3.org/2005/Atom\"><channel><title>Noteflakes</title><link>https://noteflakes.com/</link><description>A website by Sharon Rosner</description><language>en-us</language><pubDate>#{EscapeUtils.escape_xml(Time.now.httpdate)}</pubDate><atom:link href=\"https://noteflakes.com/feeds/rss\" rel=\"self\" type=\"application/rss+xml\" />"
  article_entries = articles.reverse
  article_entries.each { |e|
    buffer << "<item><title>#{e[:title]}</title><link>#{EscapeUtils.escape_xml("https://noteflakes.com#{e[:url]}")}</link><guid>#{EscapeUtils.escape_xml("https://noteflakes.com#{e[:url]}")}</guid><pubDate>#{EscapeUtils.escape_xml(e[:date].to_time.httpdate)}</pubDate><description>#{EscapeUtils.escape_xml(e[:html_content])}</description></item>"
  }
  buffer << '</channel></rss>'
  buffer
}

tmpl3 = ->(articles:) {
  "<rss version=\"2.0\" xmlns:atom=\"http://www.w3.org/2005/Atom\"><channel><title>Noteflakes</title><link>https://noteflakes.com/</link><description>A website by Sharon Rosner</description><language>en-us</language><pubDate>#{EscapeUtils.escape_xml(Time.now.httpdate)}</pubDate><atom:link href=\"https://noteflakes.com/feeds/rss\" rel=\"self\" type=\"application/rss+xml\" />#{
    article_entries = articles.reverse
    buffer = +''
    article_entries.each { |e|
      buffer << "<item><title>#{e[:title]}</title><link>#{EscapeUtils.escape_xml("https://noteflakes.com#{e[:url]}")}</link><guid>#{EscapeUtils.escape_xml("https://noteflakes.com#{e[:url]}")}</guid><pubDate>#{EscapeUtils.escape_xml(e[:date].to_time.httpdate)}</pubDate><description>#{EscapeUtils.escape_xml(e[:html_content])}</description></item>"
    }
    buffer
    }</channel></rss>"
}

#################################################################################

class HTMLString < String
end

class FunctionalRenderer
  def render(*a, **b, &proc)
    instance_exec(*a, **b, &proc)
  end

  def method_missing(sym, *args)
    define_tag_method(sym)
    send(sym, *args)
    # tag(sym, *args)
  end

  def tag(name, *args)
    props = args.first.is_a?(Hash) ? args.shift : nil
    HTMLString.new(
      (args.size == 0) \
        ? "<#{name}#{format_tag_attributes(props)} />"
        : "<#{name}#{format_tag_attributes(props)}>#{to_html(args)}</#{name}>"
    )
  end

  S_TAG_METHOD_LINE = __LINE__ - 9
  S_TAG_METHOD = <<~EOF
    def %<tag>s(*args, &block)
      props = args.first.is_a?(Hash) ? args.shift : nil
      HTMLString.new(
        (args.size == 0) \
          ? "<%<tag>s\#{format_tag_attributes(props)} />"
          : "<%<tag>s\#{format_tag_attributes(props)}>\#{to_html(args)}</%<tag>s>"
      )
    end
  EOF

  def define_tag_method(name)
    code = S_TAG_METHOD % {
      tag: name,
    }
    self.class.class_eval(code, __FILE__, S_TAG_METHOD_LINE)
  end

  def map(coll, &block)
    HTMLString.new(
      coll.map { |i| instance_exec(i, &block) }.join
    )
  end

  def format_tag_attributes(props)
    return '' unless props
    props.map { |k, v| " #{k}=\"#{v}\""}.join
  end

  def to_html(value)
    case value
    when Array
      HTMLString.new(value.map { |v| to_html(v) }.join)
    when HTMLString
      value
    else
      HTMLString.new(EscapeUtils.escape_xml(value))
    end
  end
end

ftmpl = ->(articles:) {
  rss({version: '2.0', 'xmlns:atom' => 'http://www.w3.org/2005/Atom'},
    channel(
      title('Noteflakes'),
      link('https://noteflakes.com/'),
      description('A website by Sharon Rosner'),
      language('en-us'),
      pubDate(Time.now.httpdate),
      tag(
        'atom:link',
        href: "https://noteflakes.com/feeds/rss",
        rel:  "self",
        type: "application/rss+xml"
      ),
      map(articles.reverse) { |e|
        item(
          title(e[:title]),
          link("https://noteflakes.com#{e[:url]}"),
          guid("https://noteflakes.com#{e[:url]}"),
          pubDate(e[:date].to_time.httpdate),
          description(e[:html_content])
        )
      }
    )
  )
}

ftmpl_compiled = ->(articles:) {
  "<rss version=\"2.0\" xmlns:atom=\"http://www.w3.org/2005/Atom\"><channel><title>Noteflakes</title><link>https://noteflakes.com/</link><description>A website by Sharon Rosner</description><language>en-us</language><pubDate>#{EscapeUtils.escape_xml(Time.now.httpdate)}</pubDate><atom:link href=\"https://noteflakes.com/feeds/rss\" rel=\"self\" type=\"application/rss+xml\" />#{
    articles.reverse.map { |e|
      "<item><title>#{e[:title]}</title><link>#{EscapeUtils.escape_xml("https://noteflakes.com#{e[:url]}")}</link><guid>#{EscapeUtils.escape_xml("https://noteflakes.com#{e[:url]}")}</guid><pubDate>#{EscapeUtils.escape_xml(e[:date].to_time.httpdate)}</pubDate><description>#{EscapeUtils.escape_xml(e[:html_content])}</description></item>"
    }.join
  }</channel></rss>"
}


################################################################################

r1 = tmpl1.render(**props)
r2 = tmpl2.call(**props)
r3 = tmpl3.call(**props)

fr = FunctionalRenderer.new
r4 = fr.render(**props, &ftmpl)

r5 = ftmpl_compiled.call(**props)

raise unless r1 == r2
raise unless r1 == r3
raise unless r1 == r4
raise unless r1 == r5

# puts 'Warming up for jit'

1000.times {
  r1 = tmpl1.render(**props)
  r2 = tmpl2.call(**props)
  r3 = tmpl3.call(**props)
  r4 = fr.render(**props, &ftmpl)
  r5 = ftmpl_compiled.call(**props)
}

Benchmark.ips do |x|
  x.config(:time => 3, :warmup => 1)

  x.report("original") { tmpl1.render(**props) }
  x.report("compiled 1") { tmpl2.call(**props) }
  # x.report("compiled 2") { tmpl3.call(**props) }
  x.report('functional') { fr.render(**props, &ftmpl) }
  x.report('compiled 3') { ftmpl_compiled.call(**props) }

  x.compare!
end
