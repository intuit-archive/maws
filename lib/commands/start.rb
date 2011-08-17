require 'lib/command'

class Start < Command
  def run!
    @selected_instances.each {|i| i.start}
  end
end