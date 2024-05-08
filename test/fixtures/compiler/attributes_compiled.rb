->(__buffer__) {
  __buffer__ << "<br/><h1 id=\"main-title\">title</h1><div class=\"section\"><h2>foo</h2></div><h3 id=\"baz\" class=\"#{o.fuzz}\">bar</h3><h4 data-ref=\"42\">Hi</h4>"

  attrs = { class: 'klass', data_foo: 'bar' }
  __buffer__ << "<h5 #{Papercraft.format_html_attrs(attrs)}>Bye</h5>"
}
