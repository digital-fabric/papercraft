pr1 = Papercraft.html { p 'foo' }
pr2 = Papercraft.html { |x| p x }

->() {
  emit pr1
  emit pr2, 42
  br
  emit Papercraft.html { q 'bar' }
}
