require 'lib/instance'

# for ELBs aws_id is the same as their names
class Instance::ELB < Instance
  def create
     return if alive?
     info "creating ELB #{name}..."

     listeners = config(:listeners).dup || []

     server = connection.elb.create_load_balancer(name, @connection.availability_zones, listeners)
     connection.elb.configure_health_check(name, config(:health_check))

     description = server ? {:load_balancer_name => name} : {}
     sync_from_description(description)

     info "...done (ELB #{name} is ready)\n\n"
   end

  def destroy
    return unless alive?
    connection.elb.delete_load_balancer(aws_id)
    info "destroying ELB #{name}"
  end

  def add_instances(instances)
    names = instances.map{|i| i.name}
    info "adding instances to ELB #{aws_id}: #{names.join(', ')}"
    connection.elb.register_instances_with_load_balancer(aws_id, instances.map{|i| i.aws_id})
    info "...done"
  end

  def remove_instances(instances)
    names = instances.map{|i| i.name}
    info "removing instances to ELB #{aws_id}: #{names.join(', ')}"
    connection.elb.deregister_instances_with_load_balancer(aws_id, instances.map{|i| i.aws_id})
    info "...done"
  end

  def attached_instances
    instance_ids = @aws_description[:instances]
    @profile.defined_instances.select {|i| instance_ids.include?(i.aws_id)}
  end

  def enable_zones(zones)
    full_zones = zones.map {|z| command_options.region + z}
    info "enabling zones #{full_zones.join(', ')} for ELB #{aws_id}..."
    connection.elb.enable_availability_zones_for_load_balancer(aws_id, full_zones)
    info "...done"
  end

  def disable_zones(zones)
    full_zones = zones.map {|z| command_options.region + z}
    info "disabling zones #{full_zones.join(', ')} for ELB #{aws_id}"

    if enabled_availability_zones.size <= 1
      info "can't remove last remaining zone: #{enabled_availability_zones.first}"
      return
    end

    connection.elb.disable_availability_zones_for_load_balancer(aws_id, full_zones)
    info "...done"
  end

  def service
    :elb
  end

  def physical_zone
    nil
  end

  def enabled_availability_zones
    description.availability_zones
  end

  def zones_list
    (description.enabled_zones || []).join(', ')
  end

  def display_fields
    [:name, :status, :zones_list, :first_listener_info]
  end

  def first_listener_info
    return "" unless alive?
    (description.listeners || [{}]).first.to_hash.collect do |key, val|
      "#{key}=#{val}"
    end.join("; ")
  end

end
