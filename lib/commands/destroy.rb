require 'lib/command'

class Destroy < Command
  def run!
    @selected_instances.each {|i| i.destroy}
  end
end