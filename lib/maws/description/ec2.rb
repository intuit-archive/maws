class Description::EC2 < Description
  def initialize(description)
    description[:service] ||= :ec2
    @description = description
  end

  def name
    (tags && tags["Name"]) || aws_instance_id
  end

  def aws_id
    aws_instance_id
  end

  def status
    aws_state
  end

  def region_zone
    aws_availability_zone
  end

  def ebs_volumes
    block_device_mappings || []
  end

  def ebs_volume_ids
    ebs_volumes.map {|v| v[:ebs_volume_id]}
  end

  def attached_ebs_volume_ids
    ebs_volumes.find_all{|v| v[:ebs_status] == 'attached'}.map {|v| v[:ebs_volume_id]}
  end
end


# example ec2 description
# {:private_ip_address=>"10.240.7.99",
#      :service => :ec2, # this is set by maws
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
#      :tags => {"Name" => "foo-test-web-01"}
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

