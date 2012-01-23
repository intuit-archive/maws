require 'lib/command'
require 'terminal-table/import'

class Describe < Command
  def description
    "describe - prints all available AWS information for specified instances"
  end

  def run!
    instances.specified.each do |i|
      i.display.pretty_details
    end
  end

end