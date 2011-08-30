require 'lib/instance'

# for ELBs @aws_id is the same as their names
class Instance::ELB < Instance
  def aws_description=(description)
    @aws_description = description
    @aws_id = description[:load_balancer_name]
    @status = 'available' if @aws_id
  end

  def create
     return if exists_on_aws?
     info "creating ELB #{name}..."

     listeners = @role_config.listeners.dup || []

     connection.elb.create_load_balancer(name, @connection.availability_zones, listeners.shift)
     connection.elb.configure_health_check(name, @role_config.health_check)
     connection.elb.create_load_balancer_listeners(name, listeners) unless listeners.empty?

     info "...done (ELB #{name} is ready)\n\n"
   end

  def destroy
    return unless exists_on_aws?
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
