require 'spec/spec_helper'
require 'lib/aws_connection'
require 'lib/instance'
require 'lib/profile'


describe 'Instance::RDS' do
  it "before syncing is not alive" do
    @instance = Instance.new_for_service(:rds, 'rds1', nil, nil, {}, {}, {})

    @instance.should_not be_alive
  end

  describe "after syncing" do
    before do
      @instance = Instance.new_for_service(:rds, 'rds1', nil, nil, {}, {}, {})
      @instance.sync_from_description({:aws_id => 'rds1', :status => 'available'})
    end

    it "is alive" do
      @instance.should be_alive
    end

    it "has correct status and aws_id" do
      @instance.status.should == 'available'
      @instance.aws_id.should == 'rds1'
    end
  end

  describe "after resyncing" do
    before do
      @instance = Instance.new_for_service(:rds, 'rds2', nil, nil, {}, {}, {})
      @instance.sync_from_description({:aws_id => 'rds2', :status => 'available'})
      @instance.sync_from_description({:aws_id => 'rds2', :status => 'deleting'})
    end

    it "updates status" do
      @instance.status.should == 'deleting'
    end

    it "stays alive" do
      @instance.should be_alive
    end

    describe "when instance disappears from server" do
      before do
        @instance.sync_from_description(nil)
      end

      it "is not alive" do
        @instance.should_not be_alive
      end

      it "loses aws_id and has 'n/a' status" do
        @instance.aws_id.should be_nil
        @instance.status.should == 'n/a'
      end
    end
  end

  describe "when creating master" do
    before do
      mock_basic_master_rds_instance_and_connection
    end

    it "does nothing when instance already alive" do
      @instance.should_receive(:alive?).once.and_return(true)
      @instance.connection.rds.should_not_receive(:create_db_instance)

      @instance.create
    end

    it "fails without username set" do
      @role_config.master_username = nil
      @instance.connection.rds.should_not_receive(:create_db_instance)

      lambda {@instance.create}.should raise_exception(ArgumentError, "Missing required config: master_username")
    end

    it "fails without password set" do
      @role_config.master_password = nil
      @instance.connection.rds.should_not_receive(:create_db_instance)

      lambda {@instance.create}.should raise_exception(ArgumentError, "Missing required config: master_password")
    end

    it "uses correct configuration options" do
      @instance.connection.rds.should_receive(:create_db_instance).once.
          with('rds1','user','pass', {
            :engine => 'dbengine',
            :engine_version => 'dbengine-5000',
            :instance_class => 'verybigdb',
            :auto_minor_version_upgrade => true,
            :allocated_storage => 7,
            :db_name => 'dbname',
            :db_parameter_group => 'db-param-group',
            :db_security_groups => ['db-sec-group'],
            :backup_retention_period => nil,
            :preferred_backup_window => nil,
            :preferred_maintenance_window => nil,
            :multi_az => true
          }).and_return(nil)
      @instance.create
    end

    it "creates Multi-AZ RDS when scope is region" do
      @profile_role_config.scope = 'region'
      @instance.connection.rds.should_receive(:create_db_instance).once do |_,_,_,create_opts|
        create_opts[:multi_az].should be_true
        create_opts[:zone].should be_nil
        nil
      end

      @instance.create
    end

    it "creates single-zone RDS when scope is zone" do
      @profile_role_config.scope = 'zone'
      @instance.connection.rds.should_receive(:create_db_instance).once do |_,_,_,create_opts|
        create_opts[:multi_az].should be_nil
        create_opts[:availability_zone].should == 'x'
        nil
      end

      @instance.create
    end

    it "sets aws_id from create_db_instance results" do
      @instance.connection.rds.should_receive(:create_db_instance).once.
        and_return({:aws_id => 'rds1'})
      @instance.create

      @instance.aws_id.should == 'rds1'
    end

  end

  describe "when creating read replica" do
    before do
      mock_basic_master_rds_instance_and_connection
      @instance.sync_from_description({:aws_id => 'rds1'})

      @rr_role_config = @role_config.dup
      @rr_profile_role_config = @profile_role_config.dup

      @rr_role_config.replica = true
      @rr_role_config.source_role = 'master-rds'
      @rr_profile_role_config.scope = 'zone'

      @profile = Profile.new(nil, nil)
      @rr_instance = Instance.new_for_service(:rds, 'rds1-rr', nil, @profile, @rr_role_config, @rr_profile_role_config, @command_options)
      @rr_instance.connection = @instance.connection
    end

    it "looks up master by role" do
      @profile.should_receive(:select_first_instance).once.
          with(:defined, 'master-rds').once.and_return(@instance)

      @rr_instance.connection.rds.should_receive(:create_db_instance_read_replica).once.and_return(nil)
      @rr_instance.create
    end

    it "will not create a replica of a replica" do
      @profile.should_receive(:select_first_instance).and_return(@instance)
      @instance.should_receive(:valid_read_replica_source?).and_return(false)
      @rr_instance.should_not_receive(:create_db_instance_read_replica)

      @rr_instance.create
    end

    it "uses correct configuration options" do
      @profile.should_receive(:select_first_instance).and_return(@instance)
      @rr_instance.connection.rds.should_receive(:create_db_instance_read_replica).once.
          with('rds1-rr', 'rds1', {
            :instance_class => 'verybigdb',
            :availability_zone => 'x'}).and_return(nil)


      @rr_instance.create
    end

    it "sets aws_id from create_db_instance_read_replica results" do
      @profile.should_receive(:select_first_instance).and_return(@instance)
      @rr_instance.connection.rds.should_receive(:create_db_instance_read_replica).once.
          and_return({:aws_id => 'rds1-rr'})

      @rr_instance.create
      @rr_instance.aws_id.should == 'rds1-rr'
    end
  end

  describe "when destroying" do
    before do
      mock_basic_master_rds_instance_and_connection
    end

    it "does nothing if the instance is not alive" do
      @instance.should_receive(:alive?).once.and_return(false)
      @instance.connection.rds.should_not_receive(:delete_db_instance)

      @instance.destroy
    end

    it "does nothing if the instance is not in the right state" do
      @instance.should_receive(:alive?).once.and_return(true)
      @instance.status = 'deleting'
      @instance.connection.rds.should_not_receive(:delete_db_instance)

      @instance.destroy
    end

    %w(available failed storage-full incompatible-parameters incompatible-restore).each do |stoppable_state|
      it "destroys the instances when they are in the #{stoppable_state} state" do
          @instance.sync_from_description({:aws_id => 'rds1', :status => stoppable_state})
          @instance.connection.rds.should_receive(:delete_db_instance)
          @instance.destroy
      end
    end
  end


  it "extracts name from AWS description" do
    Instance::RDS.description_name({:aws_id => 'rds-01'}).should == "rds-01"
  end

  it "extracts aws_id from AWS description" do
    Instance::RDS.description_aws_id({:aws_id => 'rds-02'}).should == "rds-02"
  end

  it "extracts status from AWS description" do
    Instance::RDS.description_status({:status => 'yada'}).should == "yada"
  end
end


def mock_basic_master_rds_instance_and_connection
  @role_config = mash(:engine => 'dbengine',
  :engine_version => 'dbengine-5000',
  :instance_class => 'verybigdb',
  :auto_minor_version_upgrade => true,
  :allocated_storage => 7,
  :db_name => 'dbname',
  :db_parameter_group => 'db-param-group',
  :db_security_groups => ['db-sec-group'],
  :master_username => 'user',
  :master_password => 'pass')

  @profile_role_config = mash({:scope => 'region'})
  @command_options = mash({:availability_zone => 'x'})

  @instance = Instance.new_for_service(:rds, 'rds1', nil, nil, @role_config, @profile_role_config, @command_options)

  @keyid, @key = aws_test_key
  @instance.connection = AwsConnection.new(@keyid, @key, mash({:region => 'us-west-1', :logger => $right_aws_logger}))
end
