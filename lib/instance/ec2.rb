require 'lib/instance'
require 'net/ssh'

# for EC2 instances @aws_id is a random id
# name is a value of 'Name' tag
class Instance::EC2 < Instance
  def create
    return if alive?
    info "creating EC2 #{name}..."
    image_id = @role_config.image_id || connection.image_id_for_image_name(@role_config.image_name)
    return if image_id.nil?
    results = connection.ec2.launch_instances(image_id,
      :availability_zone => @command_options.availability_zone,
      :key_name => config(:keypair),
      :min_count => 1,
      :max_count => 1,
      :group_ids => config(:security_groups),
      :user_data => config(:user_data),
      :instance_type => config(:instance_type))

    sync_from_description(results.first)
  end

  def create_tags
    connection.ec2.create_tags(@aws_id, {'Name' => name})
    sleep 1
    sync!

    volumes.each {|vid| connection.ec2.create_tags(vid, {'Name' => name})  }

    info "...done (#{name} is '#{aws_id}')"
  end

  def destroy
    return unless alive?
    connection.ec2.terminate_instances(@aws_id)
    info "destroying EC2 #{name} (#{@aws_id})"
  end

  def stop
    return unless alive?
    if @status == 'running'
      connection.ec2.stop_instances(@aws_id)
      info "stopping EC2 #{name} (#{@aws_id})"
    end
  end

  def start
    return unless alive?
    if @status == 'stopped'
      connection.ec2.start_instances(@aws_id)
      info "starting EC2 #{name} (#{@aws_id})"
    end
  end

  def ssh_available?
    return false unless alive? && self.dns_name && !self.dns_name.empty?

    begin
      ssh = Net::SSH.start(dns_name, "phoneyuser", {:auth_methods => ["publickey"], :timeout => 1 })
    rescue Net::SSH::AuthenticationFailed
      return true
    rescue Object
      return false
    end
  end

  def volumes
    return unless @aws_description[:block_device_mappings]
    @aws_description[:block_device_mappings].map {|dm| dm[:ebs_volume_id]}
  end

  def attached_volumes
    return unless @aws_description[:block_device_mappings]

    @aws_description[:block_device_mappings].find_all {|dm| dm[:ebs_status] == "attached"}.map {|dm| dm[:ebs_volume_id]}
  end

  def self.description_name(description)
    (description[:tags] && description[:tags]["Name"]) || description[:aws_instance_id]
  end

  def self.description_aws_id(description)
    description[:aws_instance_id]
  end

  def self.description_status(description)
    description[:aws_state]
  end

  def display_fields
    [:name, :status, :dns_name, :aws_instance_id, :aws_image_id]
  end
end

# example ec2 description
# {:private_ip_address=>"10.240.7.99",
#      :aws_image_id=>"ami-c2a3f5d4",
#      :ip_address=>"174.129.134.109",
#      :dns_name=>"ec2-174-129-134-109.compute-1.amazonaws.com",
#      :aws_instance_type=>"m1.small",
#      :aws_owner=>"826693181925",
#      :root_device_name=>"/dev/sda1",
#      :instance_class=>"elastic",
#      :aws_state=>"running",
#      :private_dns_name=>"domU-12-31-39-04-00-95.compute-1.internal",
#      :aws_reason=>"",
#      :aws_launch_time=>"2009-11-18T14:03:25.000Z",
#      :aws_reservation_id=>"r-54d38542",
#      :aws_state_code=>16,
#      :ami_launch_index=>"0",
#      :aws_availability_zone=>"us-east-1a",
#      :aws_groups=>["default"],
#      :monitoring_state=>"disabled",
#      :aws_product_codes=>[],
#      :tags => {"Name" => "bps-test-web-01"}
#      :ssh_key_name=>"",
#      :block_device_mappings=>
#       [{:ebs_status=>"attached",
#         :ebs_delete_on_termination=>true,
#         :ebs_attach_time=>"2009-11-18T14:03:34.000Z",
#         :device_name=>"/dev/sda1",
#         :ebs_volume_id=>"vol-e600f98f"},
#        {:ebs_status=>"attached",
#         :ebs_delete_on_termination=>true,
#         :ebs_attach_time=>"2009-11-18T14:03:34.000Z",
#         :device_name=>"/dev/sdk",
#         :ebs_volume_id=>"vol-f900f990"}],
#      :aws_instance_id=>"i-8ce84ae4"}

