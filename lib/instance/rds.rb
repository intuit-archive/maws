require 'lib/instance'

# for RDS instances name == @aws_id
class Instance::RDS < Instance
  def create
    return if alive?

    if @role_config.replica
      # READ REPLICA
      info "creating RDS Read Replica #{name}..."
      source_role_name = @role_config.source_role
      self_scope = config(:scope)
      source_instance = @profile.select(:first, source_role_name)

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

    sync_from_description(result)
    info "...done (RDS #{name} is being created)\n\n"
  end

  def destroy
    return unless alive?
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
    alive? && !@role_config.replica
  end

  def service
    :rds
  end

  def self.description_name(description)
    description[:aws_id]
  end

  def self.description_aws_id(description)
    description[:aws_id]
  end

  def self.description_status(description)
    description[:status]
  end

  def display_fields
    [:name, :status, :endpoint_address, :endpoint_port]
  end

end

# example rds description
# {:aws_id=>"bps-test-masterdb-1",
#  :endpoint_port=>3306,
#  :status=>"available",
#  :multi_az=>true,
#  :db_parameter_group=>{:status=>"in-sync", :name=>"default.mysql5.1"},
#  :latest_restorable_time=>"2011-09-12T20:50:58.853Z",
#  :master_username=>"root",
#  :license_model=>"general-public-license",
#  :engine=>"mysql",
#  :pending_modified_values=>{},
#  :db_security_groups=>[{:status=>"active", :name=>"default"}],
#  :engine_version=>"5.1.57",
#  :read_replica_db_instance_identifiers=>[],
#  :availability_zone=>"us-east-1a",
#  :backup_retention_period=>1,
#  :create_time=>"2011-09-12T20:47:08.521Z",
#  :auto_minor_version_upgrade=>true,
#  :preferred_backup_window=>"07:30-08:00",
#  :allocated_storage=>6,
#  :instance_class=>"db.m1.small",
#  :preferred_maintenance_window=>"mon:10:00-mon:10:30",
#  :db_name=>"bps",
#  :endpoint_address=>
#   "bps-test-masterdb-1.ck6iyjop7iqg.us-east-1.rds.amazonaws.com"}
