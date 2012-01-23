require 'lib/command'

class Destroy < Command
  def description
    "destroy - permenantly delete specified instances"
  end

  def run!
    instances.specified.alive.each {|i| i.destroy}
  end
end