require 'lib/command'

class Stop < Command
  def run!
    @selected_instances.each {|i| i.stop}
  end
end