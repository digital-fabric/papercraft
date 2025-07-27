->(__buffer__, foo: 42, bar: 43) {
  __buffer__ << "<h1>#{CGI.escape_html((foo).to_s)}</h1><h2>#{CGI.escape_html("#{bar}")}</h2>"; __buffer__
}
