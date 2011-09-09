require 'lib/command'
require 'lib/trollop'

aclass ElbRemove < ElbCommand
  def run!
    elbs, instances = partition_elbs_and_instances
    return if elbs.nil? or instances.nil?

    elbs.each {|elb| elb.remove_instances(instances)}
  end
end