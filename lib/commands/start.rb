require 'lib/command'

class Start < Command
  def run!
    specified_instances.each {|i| i.start}
  end
end