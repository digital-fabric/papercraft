->(__buffer__) {
  items.each { |i|
    __buffer__ << "<p>#{CGI.escapeHTML((i).to_s)}</p>"
  }
}
