->(__buffer__) {
  __buffer__ << "<div>"
    __orig_buffer__ = __buffer__; __parts__ = __buffer__ = [];  __buffer__ << ->{
      __buffer__ << "<h1>#{CGI.escape_html((@foo).to_s)}</h1>"
    }
    __buffer__ << "<h2>baz</h2>"
    @foo = 'bar'; __buffer__ << "</div>"; __buffer__ = __orig_buffer__; __parts__.each { it.is_a?(Proc) ? it.() : (__buffer__ << it) }
}