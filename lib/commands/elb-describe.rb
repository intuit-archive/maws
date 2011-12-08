require 'lib/command'
require 'lib/elb_command'
require 'lib/trollop'

class ElbDescribe < ElbCommand
  def run!
    specified_elb_instances.each do |elb|
      title = elb.name.to_s.upcase
      instances = elb.attached_instances
      text =  "ENABLED ZONES: #{elb.enabled_availability_zones.join(', ')}\n" +
      "ATTACHED INSTANCES:\n\n" +
      instances.collect {|i| "#{i.name} (#{i.aws_id})"}.join("\n")

      pretty_describe(title, text)
    end

    if specified_elb_instances.empty?
      no_elb_message
      return
    end
  end
end