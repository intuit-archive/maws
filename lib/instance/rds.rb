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

    if @role_config.replica
      # READ REPLICA
      info "creating RDS Read Replica #{name}..."
      source_role_name = @role_config.source_role
      source_instance = @profile.select_first_instance(:defined, source_role_name)

      unless source_instance.valid_read_replica_source?
        error "...can't create read replica - source rds #{source_instance.name} is not valid (#{source_instance.status})!"
        return
      end

      result = connection.rds.create_db_instance_read_replica(name, source_instance.name,
                      :instance_class => @role_config.instance_class,
                      :availability_zone => @command_options.availability_zone)
    else
      # MASTER DB
      create_opts = {}
      create_opts[:engine] = config(:engine)
      create_opts[:engine_version] = config(:engine_version)
      create_opts[:instance_class] = config(:instance_class)
      create_opts[:auto_minor_version_upgrade] = config(:auto_minor_version_upgrade)
      create_opts[:allocated_storage] = config(:allocated_storage)
      create_opts[:db_name] = config(:db_name)
      create_opts[:db_parameter_group] = config(:db_parameter_group)
      create_opts[:db_security_groups] = config(:db_security_groups)
      create_opts[:backup_retention_period] = config(:backup_retention_period)
      create_opts[:preferred_backup_window] = config(:preferred_backup_window)
      create_opts[:preferred_maintenance_window] = config(:preferred_maintenance_window)

      if config(:scope).eql?("region")
        create_opts[:multi_az] = true
      else
        create_opts[:availability_zone] = @command_options.availability_zone
      end

      master_username = config(:master_username, true)
      master_password = config(:master_password, true)

      info "creating RDS #{name}..."
      result = connection.rds.create_db_instance(name, master_username, master_password, create_opts)
    end

    self.aws_description = result
    info "...done (RDS #{name} is ready)\n\n"
  end

  def destroy
    return unless exists_on_aws?
    stoppable_states = %w(available failed storage-full incompatible-parameters incompatible-restore)
    unless stoppable_states.include? @status
      info "can't destroy RDS #{@aws_id} while it is #{@status}"
      return
    end
    connection.rds.delete_db_instance(@aws_id, :skip_final_snapshot => true)
    info "destroying RDS #{@aws_id}"
  end

  def start
    # do nothing
  end

  def stop
  end

  def valid_read_replica_source?
    exists_on_aws? && !@role_config.replica
  end

  def self.description_name(description)
    description[:aws_id]
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