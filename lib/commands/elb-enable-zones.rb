require 'lib/command'
require 'lib/elb_command'
require 'lib/trollop'

class ElbEnableZones < ElbCommand
  def description
    "elb-enable-zones - add entire zones to specified ELBs (zones must exist)"
  end


  def add_specific_options(parser)
    parser.opt :zones, "Zones to enable", :short => '-z', :type => :strings
  end

  def run!
    instances.specified.with_service(:elb).each {|elb| elb.enable_zones(options.zones)}
  end
end