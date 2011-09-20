require 'lib/instance'

# for EC2 instances @aws_id is a random id
# name is a value of 'Name' tag
class Instance::EBS < Instance

  def destroy
    connection.ec2.delete_volume(@aws_id)
    info "destroying EBS volume #{name}:#{device} (#{@aws_id})"
  end

  def attached?
    aws_attachment_status == 'attached'
  end

  def attached_to_instance_id
    return "" unless attached_instance_name
    aws_device[:aws_instance_id]
  end

  def self.description_name(description)
    (description[:tags] && description[:tags]["Name"]) || description[:aws_id]
  end

  def self.description_aws_id(description)
    description[:aws_id]
  end

  def self.description_status(description)
    description[:aws_status]
  end

  def display_fields
    if attached?
      [:name, :device, :aws_id, :aws_status, :attachment_status, :aws_instance_id]
    else
      [:name, :aws_id, :aws_status]
    end
  end

  def device
    aws_device
  end

  def attachment_status
    aws_attachment_status
  end

end

# example EBS volume descriptions
# [{:aws_size              => 94,
#      :aws_device            => "/dev/sdc",
#      :aws_attachment_status => "attached",
#      :zone                  => "merlot",
#      :snapshot_id           => nil,
#      :aws_attached_at       => "2008-06-18T08:19:28.000Z",
#      :aws_status            => "in-use",
#      :aws_id                => "vol-60957009",
#      :aws_created_at        => "2008-06-18T08:19:20.000Z",
#      :aws_instance_id       => "i-c014c0a9"},
#     {:aws_size       => 1,
#      :zone           => "merlot",
#      :snapshot_id    => nil,
#      :aws_status     => "available",
#      :aws_id         => "vol-58957031",
#      :aws_created_at => Wed Jun 18 08:19:21 UTC 2008,}]