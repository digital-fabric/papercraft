->(__buffer__) {
  __buffer__ << "#{P2.render_emit_call(pr1)}#{P2.render_emit_call(pr2, 42)}<br>#{P2.render_emit_call(P2.html { q 'bar' })}"; __buffer__
}
