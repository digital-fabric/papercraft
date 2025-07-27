->(__buffer__) {
  __buffer__ << "<html><body><h1>Hello world</h1><p>Foo</p>"
      if 2 < 5
        __buffer__ << "<p>Bar</p>"
      end; __buffer__ << "</body></html>"
}
