require 'net/ssh'

class Net::SSH::Authentication::KeyManager
  def use_agent?
    false
  end
end
