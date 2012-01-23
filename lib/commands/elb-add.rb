require 'lib/command'
require 'lib/elb_command'
require 'lib/trollop'

class ElbAdd < ElbCommand
  def run!
    elbs, instances = partition_elbs_and_instances
    return if elbs.nil? or instances.nil?

    elbs.each {|elb| elb.add_instances(instances)}
  end
end