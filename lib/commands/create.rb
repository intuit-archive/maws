require 'lib/command'

class Create < Command
  def run!
    specified_instances.each {|i| i.create}
  end
end