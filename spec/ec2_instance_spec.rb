require 'spec/spec_helper'
require 'lib/aws_connection'
require 'lib/instance'


describe 'Instance::EC2' do
  it "before syncing is not alive" do
    @instance = Instance.new_for_service(:ec2, 'instance1', nil, nil, {}, {}, {})

    @instance.should_not be_alive
  end

  describe "after syncing" do
    before do
      @instance = Instance.new_for_service(:ec2, 'instance1', nil, nil, {}, {}, {})
      @instance.sync_from_description({:aws_instance_id => 'i-randomid1', :aws_state => 'running'})
    end

    it "is alive" do
      @instance.should be_alive
    end

    it "has correct status and aws_id" do
      @instance.status.should == 'running'
      @instance.aws_id.should == 'i-randomid1'
    end
  end

  describe "after resyncing" do
    before do
      @instance = Instance.new_for_service(:ec2, 'instance1', nil, nil, {}, {}, {})
      @instance.sync_from_description({:aws_instance_id => 'i-randomid1', :aws_state => 'running'})
      @instance.sync_from_description({:aws_instance_id => 'i-randomid1', :aws_state => 'shutting-down'})
    end

    it "updates status" do
      @instance.status.should == 'shutting-down'
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

  describe "when creating" do
    before do
      mock_basic_ec2_instance_and_connection
    end

    it "does nothing when instance already alive" do
      @instance.should_receive(:alive?).once.and_return(true)
      @instance.connection.ec2.should_not_receive(:launch_instances)

      @instance.create
    end

    it "does nothing without image id set" do
      @role_config.image_id = nil
      @instance.connection.ec2.should_not_receive(:launch_instances)

      @instance.create
    end

    it "looks up image id from image name" do
      @role_config.image_id = nil
      @role_config.image_name = 'my-favorite-image'
      @instance.connection.should_receive(:image_id_for_image_name).with('my-favorite-image').once.and_return('ami-randomid02')
      @instance.connection.ec2.should_receive(:launch_instances).once.with('ami-randomid02', anything()).and_return([{}])

      @instance.create
    end

    it "uses correct profile and role configs" do
      @instance.connection.ec2.should_receive(:launch_instances).once.
        with("ami-randomid01", {
          :availability_zone => 'z',
          :key_name => 'keypair1',
          :min_count => 1, :max_count => 1,
          :group_ids => ["secgroup1"],
          :user_data => 'abc123',
          :instance_type => 'tiny.instance'
        }).once.and_return([{}])

      @instance.create
    end

    it "sets aws_id from launch_instances results" do
      @instance.connection.ec2.should_receive(:launch_instances).once.
        and_return([{:aws_instance_id => 'i-randomid1'}])
      @instance.create

      @instance.aws_id.should == 'i-randomid1'
    end

  end

  describe "when creating tags" do
    before do
      mock_basic_ec2_instance_and_connection
      @instance.sync_from_description({:aws_instance_id => 'i-randomid2'})
    end

    it "creates name tag" do
      @instance.connection.ec2.should_not_receive(:launch_instances)
      @instance.should_receive(:sync_by_aws_id!).once.and_return(nil)
      @instance.should_receive(:volumes).once.and_return([])


      @instance.connection.ec2.should_receive(:create_tags).once.
        with('i-randomid2', {'Name' => 'instance1'}).and_return(nil)

      @instance.create_tags
    end

    it "creates same name tags for each volume" do
      @instance.connection.ec2.should_not_receive(:launch_instances)
      @instance.should_receive(:sync_by_aws_id!).once.and_return(nil)
      @instance.should_receive(:volumes).once.and_return(['vol1', 'vol2'])

      name_tag = {'Name' => 'instance1'}
      @instance.connection.ec2.should_receive(:create_tags).once.
        with('i-randomid2', name_tag).and_return(nil)

      @instance.connection.ec2.should_receive(:create_tags).once.
         with('vol1', name_tag).and_return(nil)

      @instance.connection.ec2.should_receive(:create_tags).once.
        with('vol2', name_tag).and_return(nil)

      @instance.create_tags
    end
  end

  describe "when destroying" do
    before do
      mock_basic_ec2_instance_and_connection
    end

    it "does nothing if the instance is not alive" do
      @instance.should_receive(:alive?).once.and_return(false)
      @instance.connection.ec2.should_not_receive(:terminate_instances)

      @instance.destroy
    end

    it "destroys the instances" do
      @instance.sync_from_description({:aws_instance_id => 'i-randomid2'})
      @instance.connection.ec2.should_receive(:terminate_instances).once.with('i-randomid2')

      @instance.destroy
    end
  end

  describe "when starting" do
    before do
      mock_basic_ec2_instance_and_connection
    end

    it "does nothing if instance is running" do
      @instance.sync_from_description({:aws_instance_id => 'i-randomid3', :aws_state => 'running'})
      @instance.connection.ec2.should_not_receive(:start_instances)
      @instance.start
    end

    it "starts the instance" do
      @instance.sync_from_description({:aws_instance_id => 'i-randomid3', :aws_state => 'stopped'})
      @instance.connection.ec2.should_receive(:start_instances).once.with('i-randomid3')
      @instance.start
    end
  end

  describe "when stopping" do
    before do
      mock_basic_ec2_instance_and_connection
    end

    it "does nothing if instance is stopped" do
      @instance.sync_from_description({:aws_instance_id => 'i-randomid4', :aws_state => 'stopped'})
      @instance.connection.ec2.should_not_receive(:stop_instances)
      @instance.stop
    end

    it "stops the instance" do
      @instance.sync_from_description({:aws_instance_id => 'i-randomid4', :aws_state => 'running'})
      @instance.connection.ec2.should_receive(:stop_instances).once.with('i-randomid4')
      @instance.stop
    end
  end

  it "extracts name from AWS description" do
    Instance::EC2.description_name({:tags => {"Name" => "web-1"}}).should == "web-1"
    Instance::EC2.description_name({:aws_instance_id => "i-randomid"}).should == "i-randomid"
  end

  it "extracts aws_id from AWS description" do
    Instance::EC2.description_aws_id({:aws_instance_id => "i-randomid"}).should == "i-randomid"
  end

  it "extracts status from AWS description" do
    Instance::EC2.description_status({:aws_state => "running"}).should == "running"
  end

  it "lists attached EBS volumes" do
    mock_basic_ec2_instance_and_connection
    @instance.sync_from_description({
      :aws_instance_id => 'i-randomid4',
      :aws_state => 'running',
      :block_device_mappings=>
          [{:ebs_status=>"available",
            :ebs_delete_on_termination=>true,
            :ebs_attach_time=>"2009-11-18T14:03:34.000Z",
            :device_name=>"/dev/sda1",
            :ebs_volume_id=>"vol-e600f98f"},
           {:ebs_status=>"attached",
            :ebs_delete_on_termination=>true,
            :ebs_attach_time=>"2009-11-18T14:03:34.000Z",
            :device_name=>"/dev/sdk",
            :ebs_volume_id=>"vol-f900f990"}]})

    @instance.attached_volumes.should == ["vol-f900f990"]
  end
end


def mock_basic_ec2_instance_and_connection
  @role_config = mash({:image_id => "ami-randomid01", :security_groups => ["secgroup1"], :user_data => 'abc123', :instance_type => 'tiny.instance'})
  @profile_role_config = mash({:keypair => "keypair1"})
  @command_options = mash({:availability_zone => 'z'})
  @instance = Instance.new_for_service(:ec2, 'instance1', nil, nil, @role_config, @profile_role_config, @command_options)

  @keyid, @key = aws_test_key
  @instance.connection = AwsConnection.new(@keyid, @key, mash({:region => 'us-west-1', :logger => $right_aws_logger}))

  # don't wait for the server to respond (we're mocking the server)
  @instance.stub!(:sleep).and_return(nil)
end