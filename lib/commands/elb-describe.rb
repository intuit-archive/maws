require 'lib/command'
require 'lib/elb_command'
require 'lib/trollop'

class ElbDescribe < ElbCommand
  def description
    "elb-describe - prints detailed information about all specified ELBs"
  end

  def run!
    elbs = instances.specified.with_service(:elb)

    elbs.each do |elb|
      title = elb.name.to_s.upcase
      instances = elb.attached_instances
      text =  "ENABLED ZONES: #{elb.enabled_availability_zones.join(', ')}\n" +
      "ATTACHED INSTANCES:\n\n" +
      instances.collect {|i| "#{i.name} (#{i.aws_id})"}.join("\n")

      InstanceDisplay.pretty_describe(title, text)
    end
  end
end