require 'lib/instance'

# for ELBs @aws_id is the same as their names
class Instance::ELB < Instance
  def create
     return if alive?
     info "creating ELB #{name}..."

     listeners = @role_config.listeners.dup || []

     server = connection.elb.create_load_balancer(name, @connection.availability_zones, listeners)
     connection.elb.configure_health_check(name, @role_config.health_check)

     description = server ? {:load_balancer_name => name} : {}
     sync_from_description(description)

     info "...done (ELB #{name} is ready)\n\n"
   end

  def destroy
    return unless alive?
    connection.elb.delete_load_balancer(@aws_id)
    info "destroying ELB #{name} "
  end

  def start
    # do nothing
  end

  def stop
  end


  def add_instances(instances)
    names = instances.map{|i| i.name}
    info "adding instances to ELB #{@aws_id}: #{names.join(', ')}"
    connection.elb.register_instances_with_load_balancer(@aws_id, instances.map{|i| i.aws_id})
  end

  def remove_instances(instances)
    names = instances.map{|i| i.name}
    info "removing instances to ELB #{@aws_id}: #{names.join(', ')}"
    connection.elb.deregister_instances_with_load_balancer(@aws_id, instances.map{|i| i.aws_id})
  end

  def instances
    instance_ids = @aws_description[:instances]
    @profile.defined_instances.select {|i| instance_ids.include?(i.aws_id)}
  end

  def self.description_name(description)
    description[:load_balancer_name]
  end

  def self.description_aws_id(description)
    description[:load_balancer_name]
  end

  def self.description_status(description)
    'available' if description[:load_balancer_name]
  end

  def display_fields
    [:name, :status, :first_listener_info]
  end

  def first_listener_info
    return "" unless alive?
    (aws_description[:listeners] || [{}]).first.to_hash.collect do |key, val|
      "#{key}=#{val}"
    end.join("; ")
  end

end

# example elb description
# {:availability_zones=>["us-east-1c"],
#  :dns_name=>"bps-lb-110916812.us-east-1.elb.amazonaws.com",
#  :created_time=>"2011-07-06T23:50:06.040Z",
#  :health_check=>
#   {:timeout=>5,
#    :target=>"HTTP:80/",
#    :interval=>30,
#    :healthy_threshold=>6,
#    :unhealthy_threshold=>2},
#  :instances=>["i-0941bf68", "i-a182d6c0"],
#  :load_balancer_name=>"bps-lb",
#  :app_cookie_stickiness_policies=>[],
#  :lb_cookie_stickiness_policies=>[],
#  :listeners=>
#   [{:instance_port=>"80",
#     :protocol=>"HTTP",
#     :policy_names=>[],
#     :load_balancer_port=>"80"}]}
