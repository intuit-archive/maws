require 'maws/command'

class Stop < Command
  def description
    "stop - stop specified EC2 instances that are running"
  end

  def run!
    instances.specified.each {|i| i.stop if i.respond_to?(:stop)}
  end
end