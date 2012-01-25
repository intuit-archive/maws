class Description::ELB < Description
  def initialize(description)
    description[:service] ||= :elb
    @description = description
  end

  def region_zone
    # take from AZs it supports, ELBs always have at least one AZ
    availability_zones.first
  end

  def physical_zone
    nil
  end

  def name
    description[:load_balancer_name]
  end

  def aws_id
    description[:load_balancer_name]
  end

  def status
    'available' if description[:load_balancer_name]
  end

  def enabled_zones
    availability_zones.map {|z| z[-1,1]}
  end
end

# example elb description
# {:availability_zones=>["us-east-1c"],
#  :service => :elb, # this is set by maws
#  :dns_name=>"foo-lb-110916812.us-east-1.elb.amazonaws.com",
#  :created_time=>"2011-07-06T23:50:06.040Z",
#  :health_check=>
#   {:timeout=>5,
#    :target=>"HTTP:80/",
#    :interval=>30,
#    :healthy_threshold=>6,
#    :unhealthy_threshold=>2},
#  :instances=>["i-0941bf68", "i-a182d6c0"],
#  :load_balancer_name=>"foo-lb",
#  :app_cookie_stickiness_policies=>[],
#  :lb_cookie_stickiness_policies=>[],
#  :listeners=>
#   [{:instance_port=>"80",
#     :protocol=>"HTTP",
#     :policy_names=>[],
#     :load_balancer_port=>"80"}]}
