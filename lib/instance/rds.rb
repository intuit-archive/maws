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
    az_options = if profile.profile_for_role(role.name).config.scope == 'region' && !role.replica
      {:multi_az => true}
    else
      {:availability_zone => options.availability_zone}
    end

    if role.replica
      info "creating RDS Read Replica #{name}..."
      source_instance = profile.profile_for_role(role.name).select_one_of_role(role.source_role)
      unless source_instance.valid_read_replica_source?
        error "...can't create read replica - source rds #{source_instance.name} is not valid (#{source_instance.status})!"
        return
      end

      result = connection.rds.create_db_instance_read_replica(name, source_instance.name, :instance_class => role.instance_class)
    else
      info "creating RDS #{name}..."
      create_opts = {:instance_class => role.instance_class,
      :allocated_storage => role.allocated_storage,
      :db_security_groups => role.security_groups,
      :db_name => role.db_name || profile.profile_for_role(role.name).config.db_name}.merge(az_options)

      result = connection.rds.create_db_instance(name, role.master_username, role.master_password, create_opts)

    end

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

  def valid_read_replica_source?
    exists_on_aws? && !role.replica
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