require 'lib/instance'

# for EC2 instances @aws_id is a random id
# name is a value of 'Name' tag
class Instance::EC2 < Instance
  def aws_description=(description)
    @aws_description = description
    @aws_id = description[:aws_instance_id]
    @status = description[:aws_state]
  end

  def create
    return if exists_on_aws?
    info "creating #{name}..."
    results = connection.ec2.launch_instances(role.image_id,
      :availability_zone => options.availability_zone,
      :key_name => profile.profile_for_role(role.name).config.keypair,
      :min_count => 1,
      :max_count => 1,
      :group_ids => role.security_groups,
      :user_data => role.user_date,
      :instance_type => role.instance_type)
    self.aws_description = results.first
    sleep 1 # wait for instance to be created
    connection.ec2.create_tags(@aws_id, {'Name' => name})
    info "...done (#{name} is '#{aws_id}')"
  end

  def destroy
    return unless exists_on_aws?
    connection.ec2.terminate_instances(@aws_id)
    info "destroying EC2 #{name} (#{@aws_id})"
  end

  def stop
    return unless exists_on_aws?
    if @status == 'running'
      connection.ec2.stop_instances(@aws_id)
      info "stopping EC2 #{name} (#{@aws_id})"
    end
  end

  def start
    return unless exists_on_aws?
    if @status == 'stopped'
      connection.ec2.start_instances(@aws_id)
      info "starting EC2 #{name} (#{@aws_id})"
    end
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