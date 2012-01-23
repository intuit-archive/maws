require 'lib/command'

class VolumesCommand < Command
  def create_ebs_from_descriptions
    specified_roles = @maws.specified_roles
    specified_zones = @maws.specified_zones

    connection.ebs_descriptions.map { |description|
      instance = description.create_instance(self, @config)
      next unless instance.name
      instances.add(instance)
      instance.groups << "aws"
      if specified_roles.include?(instance.role) && specified_zones.include?(instance.zone)
        instance.groups << "specified"
      end
    }


    info "\n"
    info "EBS:"
    info "TOTAL #{@config.profile.name.upcase} EBS VOLUMES ON AWS: #{instances.aws.ebs.count}  "
    info "TOTAL EBS VOLUMES SELECTED: #{instances.ebs.specified.count}"
    info "TOTAL EBS VOLUMES SELECTED ON AWS: #{instances.ebs.specified.aws.count}"
  end

  def run!
    create_ebs_from_descriptions
  end
end