require 'lib/command'
require 'lib/elb_command'
require 'lib/trollop'

class ElbEnableZones < ElbCommand
  def add_specific_options(parser)
    parser.opt :zones, "Zones to enable", :short => '-z', :type => :strings
  end

  def run!
    return if specified_elb_instances.empty?

    specified_elb_instances.each {|elb| elb.enable_zones(options.zones)}
  end
end