require 'spec/spec_helper'
require 'lib/aws_connection'
require 'lib/instance'



describe 'Instance::ELB' do
  it "before syncing is not alive" do
    @instance = Instance.new_for_service(:elb, 'elb1', nil, nil, {}, {}, {})

    @instance.should_not be_alive
  end

  describe "after syncing" do
    before do
      @instance = Instance.new_for_service(:elb, 'elb1', nil, nil, {}, {}, {})
      @instance.sync_from_description({:load_balancer_name => 'elb1'})
    end

    it "is alive" do
      @instance.should be_alive
    end

    it "has correct status and aws_id" do
      @instance.status.should == 'available'
      @instance.aws_id.should == 'elb1'
    end
  end

  describe "after resyncing" do
    before do
      @instance = Instance.new_for_service(:elb, 'elb2', nil, nil, {}, {}, {})
      @instance.sync_from_description({:load_balancer_name => 'elb1'})
      @instance.sync_from_description({:load_balancer_name => 'elb1'})
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
      mock_basic_elb_instance_and_connection
    end

    it "does nothing when instance already alive" do
      @instance.should_receive(:alive?).once.and_return(true)
      @instance.connection.elb.should_not_receive(:create_db_instance)

      @instance.create
    end

    it "uses correct configuration options" do
      @instance.connection.elb.should_receive(:create_load_balancer).once.
          with('elb1', %w(x y z), [mash({
            :protocol => 'http',
            :load_balancer_port => 3080,
            :instance_port => 4080 })]).
          and_return('elb1.amazonaws.com')

      @instance.connection.elb.should_receive(:configure_health_check).once.
        with('elb1',
          mash({
            :target => "HTTP:80/heartbeat",
            :interval => 99,
            :timeout => 11,
            :healthy_threshold => 7,
            :unhealthy_threshold => 1,
          })).
        and_return(nil)

      @instance.create
    end

    it "sets aws_id and status from create_load_balancer results" do
      @instance.connection.elb.should_receive(:create_load_balancer).once.
        and_return('elb1.amazonaws.com')
      @instance.connection.elb.should_receive(:configure_health_check).once.and_return(nil)

      @instance.create

      @instance.aws_id.should == 'elb1'
      @instance.status.should == 'available'
    end

  end

  describe "when destroying" do
    before do
      mock_basic_elb_instance_and_connection
    end

    it "does nothing if the instance is not alive" do
      @instance.should_receive(:alive?).once.and_return(false)
      @instance.connection.elb.should_not_receive(:delete_load_balancer)

      @instance.destroy
    end

    it "destroys load balancer" do
      @instance.sync_from_description({:load_balancer_name => 'elb-01'})
      @instance.connection.elb.should_receive(:delete_load_balancer).once.
        with('elb-01')

      @instance.destroy
    end

  end


  it "extracts name from AWS description" do
    Instance::ELB.description_name({:load_balancer_name => 'elb-01'}).should == "elb-01"
  end

  it "extracts aws_id from AWS description" do
    Instance::ELB.description_aws_id({:load_balancer_name => 'elb-02'}).should == "elb-02"
  end

  it "sets status to available if AWS description is valid" do
    Instance::ELB.description_status({:load_balancer_name => 'elb-03'}).should == "available"
  end
end


def mock_basic_elb_instance_and_connection
  @role_config = mash({
    :listeners => [
      { :protocol => 'http',
        :load_balancer_port => 3080,
        :instance_port => 4080 }],
    :health_check => {
      :target => "HTTP:80/heartbeat",
      :interval => 99,
      :timeout => 11,
      :healthy_threshold => 7,
      :unhealthy_threshold => 1,
    }})


  @profile_role_config = mash({})
  @command_options = mash({:availability_zone => 'z'})
  @instance = Instance.new_for_service(:elb, 'elb1', nil, nil, @role_config, @profile_role_config, @command_options)

  @keyid, @key = aws_test_key
  @instance.connection = AwsConnection.new(@keyid, @key, mash({:region => 'us-west-1', :logger => $right_aws_logger}))
  @instance.connection.stub!(:availability_zones).and_return(['x','y','z'])
end