class Description::RDS < Description
  def initialize(description)
    description[:service] ||= :rds
    @description = description
  end

  def name
    aws_id
  end

  def region_zone
    availability_zone
  end

  def logical_zone
    # parse from name if not multi_az, otherwise nil
    super unless multi_az
  end

end

# example rds description
# {:aws_id=>"foo-test-masterdb-1",
#  :service => :rds, # this is set by maws
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
#  :db_name=>"foo",
#  :endpoint_address=>
#   "foo-test-masterdb-1.ck6iyjop7iqg.us-east-1.rds.amazonaws.com"}
