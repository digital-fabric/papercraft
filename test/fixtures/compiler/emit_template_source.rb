pr1 = P2.html { p 'foo' }
pr2 = P2.html { |x| p x }

->() {
  emit pr1
  emit pr2, 42
  br
  emit P2.html { q 'bar' }
}
