require 'lib/instance'

# for EC2 instances aws_id is a random id
# name is a value of 'Name' tag
class Instance::EBS < Instance

  def destroy
    connection.ec2.delete_volume(aws_id)
    info "destroying EBS volume #{name}:#{device} (#{aws_id})"
  end

  def attached?
    aws_attachment_status == 'attached'
  end

  def attached_to_instance_id
    return "" unless attached_instance_name
    device[:aws_instance_id]
  end

  def display_fields
    if attached?
      super + [:device, :aws_id, :attachment_status, :aws_instance_id]
    else
      super + [:aws_id]
    end
  end

  def service
    :ebs
  end

  def physical_zone
    super || @config.available_zones.first
  end

  def device
    description.aws_device
  end

  def attachment_status
    description.aws_attachment_status
  end
end

