require 'hashie'

class Hashie::Mash
  undef :count # usually count is the number of keys mash has
end

def mash(x = {})
  Hashie::Mash.new x
end