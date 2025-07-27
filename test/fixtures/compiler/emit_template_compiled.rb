->(__buffer__) {
  __buffer__ << "#{Papercraft.render_emit_call(pr1)}#{Papercraft.render_emit_call(pr2, 42)}<br>#{Papercraft.render_emit_call(Papercraft.html { q 'bar' })}"; __buffer__
}
