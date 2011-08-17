require 'lib/instance'

class Instance::RDS < Instance
  def aws_description=(description)
    @aws_description = description
    @aws_id = description[:aws_id]
    @status = description[:status]
  end
end

def create
  return if exists_on_aws?
  info "creating #{name}..."
  results = connection.ec2.launch_instances(role.image_id,
    :min_count => 1,
    :max_count => 1,
    :group_ids => role.security_groups,
    :user_data => role.user_date,
    :instance_type => role.instance_type)
  self.aws_description = results.first
  connection.ec2.create_tags(@aws_id, {'Name' => name})
  info "...done (#{name} is '#{aws_id}')"
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