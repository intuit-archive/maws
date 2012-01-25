class Description::EBS < Description
  def initialize(description)
    description[:service] ||= :ebs
    @description = description
  end

  def name
    (tags && tags["Name"]) || aws_id
  end

  def status
    aws_status
  end

  def region_zone
    description[:zone]
  end
end

# example EBS volume descriptions
#  [{:snapshot_id=>"snap-a536ecc0",
#    :service => :ebs, # this is set by maws
#    :aws_id=>"vol-85fe67e8",
#    :aws_status=>"available",
#    :aws_created_at=>"2011-12-15T18:47:26.000Z",
#    :zone=>"us-east-1c",
#    :tags=>{},
#    :aws_size=>100},
#   {:aws_device=>"/dev/sda",
#    :snapshot_id=>"snap-35446157",
#    :aws_id=>"vol-6ce63401",
#    :aws_status=>"in-use",
#    :aws_created_at=>"2011-11-19T22:45:03.000Z",
#    :aws_attachment_status=>"attached",
#    :zone=>"us-east-1c",
#    :tags=>{"Name"=>"foo-e2e-control-1"},
#    :aws_size=>6,
#    :aws_attached_at=>"2011-11-19T22:45:24.000Z",
#    :aws_instance_id=>"i-fd126f9e",
#    :delete_on_termination=>true},
