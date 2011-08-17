require 'lib/instance'

# for RDS instances name == @aws_id
class Instance::RDS < Instance
  def aws_description=(description)
    @aws_description = description
    @aws_id = description[:aws_id]
    @status = description[:status]
  end

  def create
    return if exists_on_aws?
    info "creating #{name}..."
    result = connection.rds.create_db_instance(name, role.master_username, role.master_password,
      :availability_zone => @availability_zone,
      :instance_class => role.instance_class,
      :allocated_storage => role.allocated_storage,
      :db_security_groups => role.security_groups,
      :db_name => role.db_name || profile_for_role_config.db_name)
    self.aws_description = result
    info "...done (RDS #{name} is ready)"
  end

  def destroy
    return unless exists_on_aws?
    stoppable_states = %w(available failed storage-full incompatible-parameters incompatible-restore)
    unless stoppable_states.include? @status
      info "can't destroy RDS #{@aws_id} while it is #{@status}"
      return
    end
    connection.rds.delete_db_instance(@aws_id)
    info "destroying RDS #{@aws_id}"
  end

  def start
    # do nothing
  end

  def stop
  end

end

# example rds description
# {:instance_class=>"db.m1.small",
#      :status=>"creating",
#      :backup_retention_period=>1,
#      :read_replica_db_instance_identifiers=>["kd-delete-me-01-replica-01"],
#      :master_username=>"username",
#      :preferred_maintenance_window=>"sun:05:00-sun:09:00",
#      :db_parameter_group=>{:status=>"in-sync", :name=>"default.mysql5.1"},
#      :multi_az=>true,
#      :engine=>"mysql",
#      :auto_minor_version_upgrade=>false,
#      :allocated_storage=>25,
#      :availability_zone=>"us-east-1d",
#      :aws_id=>"kd-delete-me-01",
#      :preferred_backup_window=>"03:00-05:00",
#      :engine_version=>"5.1.50",
#      :pending_modified_values=>{:master_user_password=>"****"},
#      :db_security_groups=>[{:status=>"active", :name=>"default"}