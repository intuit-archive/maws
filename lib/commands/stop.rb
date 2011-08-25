require 'lib/command'

class Stop < Command
  def run!
    specified_instances.each {|i| i.stop}
  end
end