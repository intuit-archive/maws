require 'lib/command'
require 'lib/trollop'

class ElbAdd < Command
  def run!
    puts "elb add!"

    # ap @connection.availability_zones
    # ap @connection.elb_descriptions[0]
  end
end