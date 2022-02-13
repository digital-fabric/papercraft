<h1 align="center">
  <img src="papercraft.png">
  <br>
  Papercraft
</h1>

<h4 align="center">Composable templating for Ruby</h4>

<p align="center">
  <a href="http://rubygems.org/gems/papercraft">
    <img src="https://badge.fury.io/rb/papercraft.svg" alt="Ruby gem">
  </a>
  <a href="https://github.com/digital-fabric/papercraft/actions?query=workflow%3ATests">
    <img src="https://github.com/digital-fabric/papercraft/workflows/Tests/badge.svg" alt="Tests">
  </a>
  <a href="https://github.com/digital-fabric/papercraft/blob/master/LICENSE">
    <img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="MIT License">
  </a>
</p>

<p align="center">
  <a href="https://www.rubydoc.info/gems/papercraft">API reference</a>
</p>

## What is Papercraft?

Papercraft is a templating engine for dynamically producing HTML, XML or JSON.
Papercraft templates are expressed in plain Ruby, leading to easier debugging,
better protection against HTML/XML injection attacks, and better code reuse.

Papercraft templates can be composed in a variety of ways, facilitating the
usage of layout templates, and enabling a component-oriented approach to
building complex web interfaces.

In Papercraft, dynamic data is passed explicitly to the template as block
arguments, making the data flow easy to follow and understand. Papercraft also
lets developers create derivative templates using full or partial parameter
application.

Papercraft includes built-in support for rendering Markdown (using
[Kramdown](https://github.com/gettalong/kramdown/)), as well as support for
creating template extensions in order to allow the creation of component
libraries.

```ruby
require 'papercraft'

page = Papercraft.html { |*args|
  html {
    head { title 'Title' }
    body { emit_yield *args }
  }
}
page.render { p 'foo' }
#=> "<html><head><title>Title</title></head><body><p>foo</p></body></html>"

hello = page.apply { |name| h1 "Hello, #{name}!" }
hello.render('world')
#=> "<html><head><title>Title</title></head><body><h1>Hello, world!</h1></body></html>"
```

## Table of content

- [Installing papercraft](#installing-papercraft)
- [Basic usage](#basic-usage)
- [Adding tags](#adding-tags)
- [Template parameters](#template-parameters)
- [Template logic](#template-logic)
- [Template blocks](#template-blocks)
- [Plain procs as templates](#plain-procs-as-templates)
- [Template composition](#template-composition)
- [Parameter and block application](#parameter-and-block-application)
- [Higher-order templates](#higher-order-templates)
- [Layout template composition](#layout-template-composition)
- [Emitting raw HTML](#emitting-raw-html)
- [Emitting a string with HTML Encoding](#emitting-a-string-with-html-encoding)
- [Emitting Markdown](#emitting-markdown)
- [Working with MIME types](#working-with-mime-types)
- [Deferred evaluation](#deferred-evaluation)
- [Papercraft extensions](#papercraft-extensions)
- [XML templates](#xml-templates)
- [JSON templates](#json-templates)
- [API Reference](#api-reference)

## Installing Papercraft

Using bundler:

```ruby
gem 'papercraft'
```

Or manually:

```bash
$ gem install papercraft
```

## Basic usage

To create an HTML template use `Papercraft.html`:

```ruby
require 'papercraft'

html = Papercraft.html {
  div(id: 'greeter') { p 'Hello!' }
}
```

(You can also use `Papercraft.xml` and `Papercraft.json` to create XML and JSON
templates, respectively.)

Rendering a template is done using `#render`:

```ruby
html.render #=> "<div id="greeter"><p>Hello!</p></div>"
```

## Adding tags

Tags are added using unqualified method calls, and can be nested using blocks:

```ruby
Papercraft.html {
  html {
    head {
      title 'page title'
    }
    body {
      article {
        h1 'article title'
      }
    }
  }
}
```

Tag methods accept a string argument, a block, or no argument at all:

```ruby
Papercraft.html { p 'hello' }.render #=> "<p>hello</p>"

Papercraft.html { p { span '1'; span '2' } }.render #=> "<p><span>1</span><span>2</span></p>"

Papercraft.html { hr() }.render #=> "<hr/>"
```

Tag methods also accept tag attributes, given as a hash:

```ruby
Papercraft.html { img src: '/my.gif' }.render #=> "<img src="/my.gif"/>

Papercraft.html { p "foobar", class: 'important' }.render #=> "<p class=\"important\">foobar</p>"
```

## Tag and attribute formatting

Papercraft does not make any presumption about what tags and attributes you can
use. You can mix upper and lower case letters, and you can include arbitrary
characters in tag and attribute names. However, in order to best adhere to the
HTML and XML specs and common practices, tag names and attributes will be
formatted according to the following rules, depending on the template type:

- HTML: underscores are converted to dashes:

  ```ruby
  Papercraft.html {
    foo_bar { p 'Hello', data_name: 'world' }
  }.render #=> '<foo-bar><p data-name="world">Hello</p></foo-bar>'
  ```

- XML: underscores are converted to dashes, double underscores are converted to
  colons:

  ```ruby
  Papercraft.xml {
    soap__Envelope(
      xmlns__soap:  'http://schemas.xmlsoap.org/soap/envelope/',
    ) { }
  }.render #=> '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"><soap:Envelope>'
  ```

If you need more precise control over tag names, you can use the `#tag` method,
which takes the tag name as its first parameter, then the rest of the parameters
normally used for tags:

```ruby
Papercraft.html {
  tag 'cra_zy__:!tag', 'foo'
}.render #=> '<cra_zy__:!tag>foo</cra_zy__:!tag>'
```

## Template parameters

In Papercraft, parameters are always passed explicitly. This means that template
parameters are specified as block parameters, and are passed to the template on
rendering:

```ruby
greeting = Papercraft.html { |name| h1 "Hello, #{name}!" }
greeting.render('world') #=> "<h1>Hello, world!</h1>"
```

Templates can also accept named parameters:

```ruby
greeting = Papercraft.html { |name:| h1 "Hello, #{name}!" }
greeting.render(name: 'world') #=> "<h1>Hello, world!</h1>"
```

## Template logic

Since Papercraft templates are just a bunch of Ruby, you can easily write your
view logic right in the template:

```ruby
Papercraft.html { |user = nil|
  if user
    span "Hello, #{user.name}!"
  else
    span "Hello, guest!"
  end
}
```

## Template blocks

Templates can also accept and render blocks by using `emit_yield`:

```ruby
page = Papercraft.html {
  html {
    body { emit_yield }
  }
}

# we pass the inner HTML
page.render { h1 'hi' }
```

## Plain procs as templates

With Papercraft you can write a template as a plain Ruby proc, and later render
it by passing it as a block to `Papercraft.html`:

```ruby
greeting = proc { |name| h1 "Hello, #{name}!" }
Papercraft.html(&greeting).render('world')
```

Components can also be expressed using lambda notation:

```ruby
greeting = ->(name) { h1 "Hello, #{name}!" }
Papercraft.html(&greeting).render('world')
```

## Template composition

Papercraft makes it easy to compose multiple templates into a whole HTML
document. A Papercraft template can contain other templates, as the following
example shows.

```ruby
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

page = Papercraft.html { |title, items|
  html5 {
    head { Title(title) }
    body { ItemList(items) }
  }
}

page.render('Hello from composed templates', [
  { id: 1, text: 'foo', checked: false },
  { id: 2, text: 'bar', checked: true }
])
```

In addition to using templates defined as constants, you can also use
non-constant templates by invoking the `#emit` method:

```ruby
greeting = -> { span "Hello, world" }

Papercraft.html {
  div {
    emit greeting
  }
}
```

## Parameter and block application

Parameters and blocks can be applied to a template without it being rendered, by
using `#apply`. This mechanism is what allows template composition and the
creation of higher-order templates.

The `#apply` method returns a new template which applies the given parameters and
or block to the original template:

```ruby
# parameter application
hello = Papercraft.html { |name| h1 "Hello, #{name}!" }
hello_world = hello.apply('world')
hello_world.render #=> "<h1>Hello, world!</h1>"

# block application
div_wrap = Papercraft.html { div { emit_yield } }
wrapped_h1 = div_wrap.apply { h1 'hi' }
wrapped_h1.render #=> "<div><h1>hi</h1></div>"

# wrap a template
wrapped_hello_world = div_wrap.apply(&hello_world)
wrapped_hello_world.render #=> "<div><h1>Hello, world!</h1></div>"
```

## Higher-order templates

Papercraft also lets you create higher-order templates, that is,
templates that take other templates as parameters, or as blocks. Higher-order
templates are handy for creating layouts, wrapping templates in arbitrary
markup, enhancing templates or injecting template parameters.

Here is a higher-order template that takes a template as parameter:

```ruby
div_wrap = Papercraft.html { |inner| div { emit inner } }
greeter = Papercraft.html { h1 'hi' }
wrapped_greeter = div_wrap.apply(greeter)
wrapped_greeter.render #=> "<div><h1>hi</h1></div>"
```

The inner template can also be passed as a block, as shown above:

```ruby
div_wrap = Papercraft.html { div { emit_yield } }
wrapped_greeter = div_wrap.apply { h1 'hi' }
wrapped_greeter.render #=> "<div><h1>hi</h1></div>"
```

## Layout template composition

One of the principal uses of higher-order templates is the creation of nested
layouts. Suppose we have a website with a number of different layouts, and we'd
like to avoid having to repeat the same code in the different layouts. We can do
this by creating a `default` page template that takes a block, then use `#apply`
to create the other templates:

```ruby
default_layout = Papercraft.html { |**params|
  html5 {
    head {
      title: params[:title]
    }
    body {
      emit_yield(**params)
    }
  }
}

article_layout = default_layout.apply { |title:, body:|
  article {
    h1 title
    emit_markdown body
  }
}

article_layout.render(
  title: 'This is a title',
  body: 'Hello from *markdown body*'
)
```

## Emitting raw HTML

Raw HTML can be emitted using `#emit`:

```ruby
wrapped = Papercraft.html { |html| div { emit html } }
wrapped.render("<h1>hi</h1>") #=> "<div><h1>hi</h1></div>"
```

## Emitting a string with HTML Encoding

To emit a string with proper HTML encoding, without wrapping it in an HTML
element, use `#text`:

```ruby
Papercraft.html { str 'hi&lo' }.render #=> "hi&amp;lo"
```

## Emitting Markdown

Markdown is rendered using the
[Kramdown](https://kramdown.gettalong.org/index.html) gem. To emit Markdown, use
`#emit_markdown`:

```ruby
template = Papercraft.html { |md| div { emit_markdown md } }
template.render("Here's some *Markdown*") #=> "<div><p>Here's some <em>Markdown</em><p>\n</div>"
```

[Kramdown
options](https://kramdown.gettalong.org/options.html#available-options) can be
specified by adding them to the `#emit_markdown` call:

```ruby
template = Papercraft.html { |md| div { emit_markdown md, auto_ids: false } }
template.render("# title") #=> "<div><h1>title</h1></div>"
```

The `#emit_markdown` method is available only to HTML templates. If you need to
render markdown in XML or JSON templates (usually for implementing RSS or JSON
feeds), you can use `Papercraft.markdown` directly:

```ruby
Papercraft.markdown('# title') #=> "<h1>title</h1>"
```

The default Kramdown options are:

```ruby
{
  entity_output: :numeric,
  syntax_highlighter: :rouge,
  input: 'GFM',
  hard_wrap: false  
}
```

The deafult options can be configured by accessing
`Papercraft.default_kramdown_options`, e.g.:

```ruby
Papercraft.default_kramdown_options[:auto_ids] = false
```

## Working with MIME types

Papercraft lets you set and interrogate a template's MIME type, in order to be
able to dynamically set the `Content-Type` HTTP response header. A template's
MIME type can be set when creating the template, e.g. `Papercraft.xml(mime_type:
'application/rss+xml')`. You can interrogate the template's MIME type using
`#mime_type`:

```ruby
# using Qeweney (https://github.com/digital-fabric/qeweney)
def serve_template(req, template)
  body = template.render
  respond(body, 'Content-Type' => template.mime_type)
end
```

## Deferred evaluation

Deferred evaluation allows deferring the rendering of parts of a template until
the last moment, thus allowing an inner template to manipulate the state of the
outer template. To in order to defer a part of a template, use `#defer`, and
include any markup in the provided block. This technique, in in conjunction with
holding state in instance variables, is an alternative to passing parameters,
which can be limiting in some situations.

A few use cases for deferred evaulation come to mind:

- Setting the page title.
- Adding a flash message to a page.
- Using templates that dynamically add static dependencies (JS and CSS) to the
  page.

The last use case is particularly interesting. Imagine a `DependencyMananger`
class that can collect JS and CSS dependencies from the different templates
integrated into the page, and adds them to the page's `<head>` element:

```ruby
default_layout = Papercraft.html { |**args|
  @dependencies = DependencyMananger.new
  head {
    defer { emit @dependencies.head_markup }
  }
  body { emit_yield **args }
}

button = proc { |text, onclick|
  @dependencies.js '/static/js/button.js'
  @dependencies.css '/static/css/button.css'

  button text, onclick: onclick
}

heading = proc { |text|
  @dependencies.js '/static/js/heading.js'
  @dependencies.css '/static/css/heading.css'

  h1 text
}

page = default_layout.apply {
  emit heading, "What's your favorite cheese?"

  emit button, 'Beaufort', 'eat_beaufort()'
  emit button, 'Mont d''or', 'eat_montdor()'
  emit button, 'Époisses', 'eat_epoisses()'
}
```

## Papercraft extensions

Papercraft extensions are modules that contain one or more methods that can be
used to render complex HTML components. Extension modules can be used by
installing them as a namespaced extension using `Papercraft::extension`.
Extensions are particularly useful when you work with CSS frameworks such as
[Bootstrap](https://getbootstrap.com/), [Tailwind](https://tailwindui.com/) or
[Primer](https://primer.style/).

For example, to create a Bootstrap card component, the following HTML markup is
needed (example taken from the [Bootstrap
docs](https://getbootstrap.com/docs/5.1/components/card/#titles-text-and-links)):

```html
<div class="card" style="width: 18rem;">
  <div class="card-body">
    <h5 class="card-title">Card title</h5>
    <h6 class="card-subtitle mb-2 text-muted">Card subtitle</h6>
    <p class="card-text">Some quick example text to build on the card title and make up the bulk of the card's content.</p>
    <a href="#" class="card-link">Card link</a>
    <a href="#" class="card-link">Another link</a>
  </div>
</div>
```

With Papercraft, we could create a `Bootstrap` extension with a `#card` method
and other associated methods:

```ruby
module BootstrapComponents
  ...

  def card(**props)
    div(class: 'card', **props) {
      div(class: 'card-body') {
        emit_yield
      }
    }
  end

  def card_title(title)
    h5 title, class: 'card-title'
  end

  ...
end

Papercraft.extension(bootstrap: BootstrapComponents)
```

The call to `Papercraft::extension` lets us access the different methods of
`BootstrapComponents` by calling `#bootstrap` inside a template. With this,
we'll be able to express the above markup as follows:

```ruby
Papercraft.html {
  bootstrap.card(style: 'width: 18rem') {
    bootstrap.card_title 'Card title'
    bootstrap.card_subtitle 'Card subtitle'
    bootstrap.card_text 'Some quick example text to build on the card title and make up the bulk of the card''s content.'
    bootstrap.card_link '#', 'Card link'
    bootstrap.card_link '#', 'Another link'
  }
}
```



## XML templates

XML templates behave largely the same as HTML templates, with a few minor
differences. XML templates employ a different encoding algorithm, and lack some
specific HTML functionality, such as emitting Markdown.

Here's an example showing how to create an RSS feed:

```ruby
rss = Papercraft.xml(mime_type: 'text/xml; charset=utf-8') { |resource:, **props|
  rss(version: '2.0', 'xmlns:atom' => 'http://www.w3.org/2005/Atom') {
    channel {
      title 'Noteflakes'
      link 'https://noteflakes.com/'
      description 'A website by Sharon Rosner'
      language 'en-us'
      pubDate Time.now.httpdate
      emit '<atom:link href="https://noteflakes.com/feeds/rss" rel="self" type="application/rss+xml" />'
      
      article_entries = resource.page_list('/articles').reverse

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
```

## JSON templates

JSON templates behave largely the same as HTML and XML templates. The only major
difference is that for adding array items you'll need to use the `#item` method:

```ruby
Papercraft.json {
  item 1
  item 2
  item 3
}.render #=> "[1,2,3]"
```

Otherwise, you can create arbitrarily complex JSON structures by mixing hashes
and arrays:

```Ruby
Papercraft.json {
  foo {
    bar {
      item nil
      item true
      item 123.456
    }
  }
}.render #=> "{\"foo\":{\"bar\":[null,true,123.456]}}"
```

Papercraft uses the [JSON gem](https://rubyapi.org/3.1/o/json) under the hood in
order to generate actual JSON.

## API Reference

The API reference for this library can be found
[here](https://www.rubydoc.info/gems/papercraft).