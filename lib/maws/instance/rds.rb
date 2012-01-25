require 'maws/instance'

# for RDS instances name == aws_id
class Instance::RDS < Instance
  def create
    return if alive?

    if config(:replica)
      # READ REPLICA
      info "creating RDS Read Replica #{name}..."
      source_role_name = config(:source_role, true)

      source_instance = instances.with_role(source_role_name).first

      if source_instance.nil?
        error "...can't create read replica - the source role '#{source_role_name}' doesn't exist"
        return
      end

      unless source_instance.valid_read_replica_source?
        error "...can't create read replica - source rds #{source_instance.name} is not valid (#{source_instance.status})!"
        return
      end

      result = connection.rds.create_db_instance_read_replica(name, source_instance.name,
                      :instance_class => config(:instance_class, true),
                      :availability_zone => region_physical_zone)
    else
      info "creating RDS #{name}..."

      # MASTER DB
      create_opts = {}
      create_opts[:engine] = config(:engine)
      create_opts[:engine_version] = config(:engine_version)
      create_opts[:instance_class] = config(:instance_class)
      create_opts[:auto_minor_version_upgrade] = config(:auto_minor_version_upgrade)
      create_opts[:allocated_storage] = config(:allocated_storage)
      create_opts[:db_name] = config(:db_name)
      create_opts[:db_parameter_group] = config(:db_parameter_group)
      create_opts[:db_security_groups] = security_groups
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

      result = connection.rds.create_db_instance(name, master_username, master_password, create_opts)
    end

    sync_from_description(result)
    info "...done (RDS #{name} is being created)\n\n"
  end

  def destroy
    return unless alive?
    stoppable_states = %w(available failed storage-full incompatible-parameters incompatible-restore)
    unless stoppable_states.include? status
      info "can't destroy RDS #{aws_id} while it is #{status}"
      return
    end
    connection.rds.delete_db_instance(aws_id, :skip_final_snapshot => true)
    info "destroying RDS #{aws_id}"
  end

  def valid_read_replica_source?
    alive? && !config(:replica)
  end

  def service
    :rds
  end

  def display_fields
    super + [:endpoint_address, :endpoint_port]
  end

end
