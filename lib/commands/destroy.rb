require 'lib/command'

class Destroy < Command
  def run!
    specified_instances.each {|i| i.destroy}
  end
end