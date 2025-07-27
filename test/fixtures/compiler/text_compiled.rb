->(__buffer__) {
  __buffer__ << "<h1>foo&amp;bar</h1><h2>#{CGI.escape_html(x.to_s)}</h2>"; __buffer__
}
