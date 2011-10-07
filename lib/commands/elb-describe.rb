require 'lib/command'
require 'lib/elb_command'
require 'lib/trollop'

class ElbDescribe < ElbCommand
  def run!
    elbs = specified_instances.select{|i| i.is_a? Instance::ELB}

    elbs.each do |elb|
      title = elb.name.to_s.upcase
      instances = elb.attached_instances
      text = "LOAD BALANCER INSTANCES:\n\n" + instances.collect {|i| "#{i.name} (#{i.aws_id})"}.join("\n")

      pretty_describe(title, text)
    end

    if elbs.empty?
      no_elb_message
      return
    end
  end
end