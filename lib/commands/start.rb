require 'lib/command'

class Start < Command
  def description
    "start - start specified EC2 instances that were stopped"
  end

  def run!
    instances.specified.each {|i| i.start if i.respond_to?(:start)}
  end
end