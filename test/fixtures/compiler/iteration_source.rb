items = [1, 2, 3, 4]

->() {
  items.each { |i|
    p i
  }

  [5, 6, 7, 8].each {
    q _1
  }
}
