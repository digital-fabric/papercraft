->(__buffer__) {
  items.each { |i|
    __buffer__ << "<p>#{CGI.escape_html((i).to_s)}</p>"
  }

  [5, 6, 7, 8].each {
    __buffer__ << "<q>#{CGI.escape_html((_1).to_s)}</q>"
  }
}
