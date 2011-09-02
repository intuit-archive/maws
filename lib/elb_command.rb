require 'lib/command'

class ElbCommand < Command
  def partition_elbs_and_instances
    elbs = specified_instances.select{|i| i.is_a? Instance::ELB}
    instances = specified_instances.select{|i| i.is_a?(Instance::EC2) && i.alive?}

    if elbs.empty?
      no_elb_message
      return
    end

    if instances.empty?
      no_ec2_message
      return
    end

    return elbs, instances
  end

  def no_elb_message
    info "no ELBs specificed"
  end

  def no_ec2_message
    info "no EC2 instances specified"
  end
end