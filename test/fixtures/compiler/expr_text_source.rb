a = Object.new
def a.zoo
  'zoozoo'
end

->() {
  h1 "#{a.zoo} - zoo"
}
