require 'lib/command'
require 'lib/elb_command'
require 'lib/trollop'

class ElbAdd < ElbCommand
  def description
    "elb-add - adds all specified EC2 instances to all specified ELBs"
  end

  def run!
    ec2s = instances.specified.with_service(:ec2)
    elbs = instances.specified.with_service(:elb)

    elbs.each {|elb| elb.add_instances(ec2s)}
  end
end

