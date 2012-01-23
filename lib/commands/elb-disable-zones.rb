require 'lib/command'
require 'lib/elb_command'
require 'lib/trollop'

class ElbDisableZones < ElbCommand
  def add_specific_options(parser)
    parser.opt :zones, "Zones to disable", :short => '-z', :type => :strings
  end

  def run!
    return if specified_elb_instances.empty?

    specified_elb_instances.each {|elb| elb.disable_zones(options.zones)}
  end
end