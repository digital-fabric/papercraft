->(__buffer__) {; __parts__ = [__buffer__.dup]; __buffer__.clear
  __parts__ << "<div>";__parts__ << ->(__b__) {
      __b__ << "<h1>#{CGI.escapeHTML((@foo).to_s)}</h1>"
    }
    @foo = 'bar'
  __parts__ << "</div>";__parts__.each { |p| p.is_a?(Proc) ? p.(__buffer__) : (__buffer__ << p) }
}
