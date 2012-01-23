require 'lib/command'
require 'lib/elb_command'
require 'lib/trollop'

class ElbDisableZones < ElbCommand
  def description
    "elb-disable-zones - remove entire zones from specified ELBs (ELBs will not allow removing the last zone)"
  end

  def add_specific_options(parser)
    parser.opt :zones, "Zones to disable", :short => '-z', :type => :strings
  end

  def run!
    instances.specified.with_service(:elb).each {|elb| elb.disable_zones(options.zones)}
  end
end