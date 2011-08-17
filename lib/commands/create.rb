require 'lib/command'

class Create < Command
  def run!
    @selected_instances.each {|i| i.create(@connection, i.name)}
  end
end