require 'lib/command'

class VolumesCommand < Command
  def sync_and_build_ebs_instances
    @ebs_instances_for_specified_roles = []

    specified_ebs_prefixes = @profile.specified_role_names.collect {|role_name|
      @profile.name + "-" + role_name
    }
    specified_ebs_prefix_regexp = Regexp.new("^" + "(" + specified_ebs_prefixes.join("|") +")")

    ebs_descriptions = @connection.ec2.describe_volumes
    ebs_descriptions.each {|description|
      name = description[:tags]["Name"] || ""
      next unless name =~ specified_ebs_prefix_regexp


      status = description[:aws_status]

      ebs = Instance.new_for_service('ebs', name, status, @profile, mash({}), mash({}), options)
      ebs.sync_from_description(description)
      ebs.connection = @connection

      @ebs_instances_for_specified_roles << ebs
    }

    @ebs_instances_for_specified_roles
  end

  def run!
    sync_and_build_ebs_instances
  end

  def default_sync_instances
    @profile.defined_instances.find_all {|i| i.is_a? Instance::EC2}
  end
end