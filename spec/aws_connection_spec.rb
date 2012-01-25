require 'spec/spec_helper'
require 'maws/connection'
require 'maws/instance'

describe 'Connection' do
  before do
    @keyid, @key = aws_test_key
    @ac = Connection.new(@keyid, @key, mash({:region => 'us-west-1', :logger => $right_aws_logger}))
  end

  describe "for EC2" do
    it "initializes the interface" do
      @ac.ec2.should_not be_nil
    end

    it "the interface uses the region specified in options" do
      c = Connection.new(@keyid, @key, mash({:region => 'ap-northeast-1', :logger => $right_aws_logger}))
      c.ec2.params[:server].should == "ap-northeast-1.ec2.amazonaws.com"
    end

    it "lists descriptions" do
      @ac.ec2.should_receive(:describe_instances).and_return([{:aws_id => "ec2_instance1"}, {:aws_id => "ec2_instance2"}])
      @ac.ec2_descriptions.should == [{:aws_id => "ec2_instance1"}, {:aws_id => "ec2_instance2"}]
    end

    it "sorts descriptions to list terminated first" do
      @ac.ec2.should_receive(:describe_instances).and_return([
        {:aws_id => "ec2_instance1", :aws_state => "running"},
        {:aws_id => "ec2_instance2", :aws_state => "terminated"},
        {:aws_id => "ec2_instance3", :aws_state => "pending"}])

      @ac.ec2_descriptions.should == ([
      {:aws_id => "ec2_instance2", :aws_state => "terminated"},
      {:aws_id => "ec2_instance1", :aws_state => "running"},
      {:aws_id => "ec2_instance3", :aws_state => "pending"}])

    end

    it "caches descriptions" do
      @ac.ec2.should_receive(:describe_instances).once.and_return([{:aws_id => "ec2_instance1"}, {:aws_id => "ec2_instance2"}])
      @ac.ec2_descriptions.should == [{:aws_id => "ec2_instance1"}, {:aws_id => "ec2_instance2"}]
      @ac.ec2_descriptions.should == [{:aws_id => "ec2_instance1"}, {:aws_id => "ec2_instance2"}]
    end

    it "clears cached descriptions" do
      @ac.ec2.should_receive(:describe_instances).twice.and_return([{:aws_id => "ec2_instance1"}, {:aws_id => "ec2_instance2"}])
      @ac.ec2_descriptions.should == [{:aws_id => "ec2_instance1"}, {:aws_id => "ec2_instance2"}]
      @ac.clear_cached_descriptions
      @ac.ec2_descriptions.should == [{:aws_id => "ec2_instance1"}, {:aws_id => "ec2_instance2"}]
    end
  end

  describe "for RDS" do
    it "initializes the interface" do
      @ac.rds.should_not be_nil
    end

    it "the interface uses the region specified in options" do
      c = Connection.new(@keyid, @key, mash({:region => 'ap-northeast-1', :logger => $right_aws_logger}))
      c.rds.params[:server].should == "ap-northeast-1.rds.amazonaws.com"
    end

    it "lists descriptions" do
      @ac.rds.should_receive(:describe_db_instances).and_return([:rds1, :rds2])
      @ac.rds_descriptions.should == [:rds1, :rds2]
    end

    it "caches descriptions" do
      @ac.rds.should_receive(:describe_db_instances).once.and_return([:rds1, :rds2])
      @ac.rds_descriptions.should == [:rds1, :rds2]
      @ac.rds_descriptions.should == [:rds1, :rds2]
    end

    it "clears cached descriptions" do
      @ac.rds.should_receive(:describe_db_instances).twice.and_return([:rds1, :rds2])
      @ac.rds_descriptions.should == [:rds1, :rds2]
      @ac.clear_cached_descriptions
      @ac.rds_descriptions.should == [:rds1, :rds2]
    end
  end

  describe "for ELB" do
    it "initializes the interface" do
      @ac.elb.should_not be_nil
    end

    it "the interface uses the region specified in options" do
      c = Connection.new(@keyid, @key, mash({:region => 'ap-northeast-1', :logger => $right_aws_logger}))
      c.elb.params[:server].should == "ap-northeast-1.elasticloadbalancing.amazonaws.com"
    end

    it "lists descriptions" do
      @ac.elb.should_receive(:describe_load_balancers).and_return([:elb1, :elb2])
      @ac.elb_descriptions.should == [:elb1, :elb2]
    end

    it "caches descriptions" do
      @ac.elb.should_receive(:describe_load_balancers).once.and_return([:elb1, :elb2])
      @ac.elb_descriptions.should == [:elb1, :elb2]
      @ac.elb_descriptions.should == [:elb1, :elb2]
    end

    it "clears cached descriptions" do
      @ac.elb.should_receive(:describe_load_balancers).twice.and_return([:elb1, :elb2])
      @ac.elb_descriptions.should == [:elb1, :elb2]
      @ac.clear_cached_descriptions
      @ac.elb_descriptions.should == [:elb1, :elb2]
    end
  end


  describe "descriptions grouped by name" do
    before do
      Instance::EC2.should_receive(:description_name).any_number_of_times.and_return {|x| x[:aws_id]}
      Instance::RDS.should_receive(:description_name).any_number_of_times.and_return {|x| x.to_s}
      Instance::ELB.should_receive(:description_name).any_number_of_times.and_return {|x| x.to_s}
    end

    it "can be selected by name" do
      @ac.ec2.should_receive(:describe_instances).once.and_return([{:aws_id => "ec2_instance1"}, {:aws_id => "ec2_instance2"}])

      @ac.description_for_name('ec2_instance1', :ec2).should == {:aws_id => "ec2_instance1"}
      @ac.description_for_name('ec2_instance2', :ec2).should == {:aws_id => "ec2_instance2"}
    end

    it "are fetched for ec2 service only" do
      @ac.ec2.should_receive(:describe_instances).once.and_return([])
      @ac.rds.should_not_receive(:describe_db_instances)
      @ac.elb.should_not_receive(:describe_load_balancers)
      @ac.description_for_name('n/a-name', :ec2)
    end

    it "are fetched for rds service only" do
      @ac.ec2.should_not_receive(:describe_instances)
      @ac.rds.should_receive(:describe_db_instances).once.and_return([])
      @ac.elb.should_not_receive(:describe_load_balancers)
      @ac.description_for_name('n/a-name', :rds)
    end

    it "are fetched for elb service only" do
      @ac.ec2.should_not_receive(:describe_instances)
      @ac.rds.should_not_receive(:describe_db_instances)
      @ac.elb.should_receive(:describe_load_balancers).once.and_return([])
      @ac.description_for_name('n/a-name', :elb)
    end

    it "are cached" do
      @ac.ec2.should_receive(:describe_instances).once.and_return([])
      @ac.description_for_name('n/a-name', :ec2)
      @ac.description_for_name('n/a-name', :ec2)
    end

    it "are re-fetched after cache is cleared" do
      @ac.ec2.should_receive(:describe_instances).twice.and_return([])
      @ac.description_for_name('n/a-name', :ec2)
      @ac.clear_cached_descriptions
      @ac.description_for_name('n/a-name', :ec2)
    end
  end

  it "lists availability zones" do
    @ac.ec2.should_receive(:describe_availability_zones).once.and_return([{:zone_name => 'zone1'}, {:zone_name => 'zone2'}])
    @ac.availability_zones.should == ['zone1', 'zone2']
  end

  it "caches availability zones" do
    @ac.ec2.should_receive(:describe_availability_zones).once.and_return([{:zone_name => 'zone1'}, {:zone_name => 'zone2'}])
    @ac.availability_zones.should == ['zone1', 'zone2']
    @ac.availability_zones.should == ['zone1', 'zone2']
  end

  it "can look up an AMI id by name" do
    @ac.ec2.should_receive(:describe_images).once.
        with(hash_including(:filters => {'tag:Name' => 'myfavoriteimage'})).
        and_return([{:aws_id => 'ami1'}])

    @ac.image_id_for_image_name('myfavoriteimage').should == 'ami1'
  end

  it "returns nil when looking up AMI that has no name" do
    @ac.ec2.should_not_receive(:describe_images)

    @ac.image_id_for_image_name(nil).should be_nil
    @ac.image_id_for_image_name("").should be_nil
  end

  it "will not return AMI id when names are duplicate" do
    @ac.ec2.should_receive(:describe_images).once.
        with(hash_including(:filters => {'tag:Name' => 'myfavoriteimage'})).
        and_return([{:aws_id => 'ami1'}, {:aws_id => 'ami2'}])

    @ac.image_id_for_image_name('myfavoriteimage').should be_nil
  end

end

