require 'spec/spec_helper'
require 'maws/connection'
require 'maws/instance'

describe 'Connection' do
  before do
    mock_config

    @c = Connection.new(@config)
  end

  describe "all service interfaces" do
    it "are not available without connecting" do
      @c.ec2.should be_nil
      @c.rds.should be_nil
      @c.elb.should be_nil
    end

    it "only EC2 is available when connecting by default" do
      @c.connect([])

      @c.ec2.should_not be_nil
      @c.rds.should be_nil
      @c.elb.should be_nil
    end

    it "all interfaces are available when specified when connecting" do
      @c.connect([:elb, :rds])

      @c.ec2.should_not be_nil
      @c.rds.should_not be_nil
      @c.elb.should_not be_nil
    end

    it "use the region specified in options" do
      @config.region = 'ap-northeast-1'
      c = Connection.new(@config)
      c.connect([:elb, :rds])

      c.ec2.params[:server].should == "ap-northeast-1.ec2.amazonaws.com"
      c.rds.params[:server].should == "ap-northeast-1.rds.amazonaws.com"
      c.elb.params[:server].should == "ap-northeast-1.elasticloadbalancing.amazonaws.com"
    end
  end

  describe "EC2 interface" do
    before do
      @c.connect([])
    end

    it "loads descriptions from AWS EC2" do
      @c.should_receive(:filter_terminated_ec2_descriptions) {|ds| ds}
      @c.should_receive(:filter_current_profile_prefix) {|ds| ds}

      @c.ec2.should_receive(:describe_instances).and_return([{:aws_id => "ec2_instance1"}, {:aws_id => "ec2_instance2"}])

      Description.should_receive(:create).with({:aws_id => "ec2_instance1", :service => :ec2}).and_return(:maws_description_1)
      Description.should_receive(:create).with({:aws_id => "ec2_instance2", :service => :ec2}).and_return(:maws_description_2)

      @c.ec2_descriptions.should == [:maws_description_1, :maws_description_2]
    end

    it "filters out extra terminated descriptions" do
      descriptions = [
        {:name => "d1", :status => "running"},

        {:name => "d2", :status => "running"},
        {:name => "d2", :status => "terminated"},
        {:name => "d2", :status => "terminated"},

        {:name => "d3", :status => "terminated"},
        {:name => "d3", :status => "terminated"},

        {:name => "d4", :status => "terminated"},
        ].map {|d| mash(d)}

      @c.should_receive(:all_ec2_descriptions).and_return(descriptions.dup)
      @c.should_receive(:filter_current_profile_prefix) {|ds| ds}

      results = @c.ec2_descriptions
      results.map {|d| d.name}.should == %w(d1 d2 d3 d4)
      results.map {|d| d.status}.should == %w(running running terminated terminated)
    end

    it "filters descriptions for the selected profile and prefix" do
      @config.profile = mash(:name => "prf")
      @config.prefix = "new"

      d1 = mash(:name => "prf-app-1", :profile => "prf", :prefix => "")
      d2 = mash(:name => "prf-app-2", :profile => "prf", :prefix => "new")
      d3 = mash(:name => "app-2", :profile => "", :prefix => "")

      @c.should_receive(:all_ec2_descriptions).and_return([d1, d2, d3])
      @c.should_receive(:filter_terminated_ec2_descriptions) {|ds| ds}

      @c.ec2_descriptions.should == [d2]
    end

  end

  describe "RDS interface" do
    it "list no descriptions when not connected" do
      @c.connect([]) # won't connect to RDS

      @c.rds_descriptions.should == []
    end

    it "loads descriptions from AWS RDS" do
      @c.connect([:rds])

      @c.should_receive(:filter_current_profile_prefix) {|ds| ds}

      @c.rds.should_receive(:describe_db_instances).and_return([{:aws_id => "rds_instance1"}, {:aws_id => "rds_instance2"}])

      Description.should_receive(:create).with({:aws_id => "rds_instance1", :service => :rds}).and_return(:maws_description_1)
      Description.should_receive(:create).with({:aws_id => "rds_instance2", :service => :rds}).and_return(:maws_description_2)

      @c.rds_descriptions.should == [:maws_description_1, :maws_description_2]
    end
  end

  describe "ELB interface" do
    it "list no descriptions when not connected" do
      @c.connect([]) # won't connect to ELB

      @c.elb_descriptions.should == []
    end

    it "loads descriptions from AWS ELB" do
      @c.connect([:elb])

      @c.should_receive(:filter_current_profile_prefix) {|ds| ds}

      @c.elb.should_receive(:describe_load_balancers).and_return([{:aws_id => "elb_instance1"}, {:aws_id => "elb_instance2"}])

      Description.should_receive(:create).with({:aws_id => "elb_instance1", :service => :elb}).and_return(:maws_description_1)
      Description.should_receive(:create).with({:aws_id => "elb_instance2", :service => :elb}).and_return(:maws_description_2)

      @c.elb_descriptions.should == [:maws_description_1, :maws_description_2]
    end
  end



  it "lists available zones" do
    @c.connect([])

    @c.ec2.should_receive(:describe_availability_zones).once.and_return(
                                  [{:zone_name => 'test-region-1a', :zone_state => "unavailable"},
                                   {:zone_name => 'test-region-1b', :zone_state => "available"}])
    @c.available_zones.should == %w(b)
  end


  describe "AMI lookup" do
    before do
      @c.connect([])
    end

    it "finds AMI id from name" do
      @c.ec2.should_receive(:describe_images).once.
          with(hash_including(:filters => {'tag:Name' => 'myfavoriteimage'})).
          and_return([{:aws_id => 'ami1'}])

      @c.image_id_for_image_name('myfavoriteimage').should == 'ami1'
    end

    it "returns nil when looking up AMI that has no name" do
      @c.ec2.should_not_receive(:describe_images)

      @c.image_id_for_image_name(nil).should be_nil
      @c.image_id_for_image_name("").should be_nil
    end

    it "will not return AMI id when names are duplicate" do
      @c.ec2.should_receive(:describe_images).once.
          with(hash_including(:filters => {'tag:Name' => 'myfavoriteimage'})).
          and_return([{:aws_id => 'ami1'}, {:aws_id => 'ami2'}])

      @c.image_id_for_image_name('myfavoriteimage').should be_nil
    end
  end

end

