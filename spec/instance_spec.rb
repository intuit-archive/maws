require 'spec/spec_helper'
require 'lib/aws_connection'
require 'lib/instance'

describe 'Instance' do
  it "creates subclasses for different services" do
    Instance.new_for_service(:ec2,'ec2-instance1', nil, nil, {}, {}, {}).should be_a_kind_of(Instance::EC2)
    Instance.new_for_service(:rds,'rds-instance1', nil, nil, {}, {}, {}).should be_a_kind_of(Instance::RDS)
    Instance.new_for_service(:elb,'elb-instance1', nil, nil, {}, {}, {}).should be_a_kind_of(Instance::ELB)
  end

  it "fails creating subclasses for unknown services" do
    lambda {Instance.new_for_service(:fake,*[nil]*6)}.should raise_exception(ArgumentError, "No such service: fake")
  end

  it "automatically looks up properties with fallback in this order: profile config, role config, aws state and command line options" do
    profile_role_config = {:a => 1}
    role_config = {:a => 2, :b => 2}
    aws_description = {:a => 3, :b => 3, :c => 3, :aws_instance_id => 'ec2id-1', :aws_state => 'running' }
    command_options = {:a => 4, :b => 4, :c => 4, :d => 4}

    instance = Instance.new_for_service(:ec2, 'instance1', nil, nil, role_config, profile_role_config, command_options)
    instance.sync_from_description(aws_description)

    instance.a.should == 1
    instance.b.should == 2
    instance.c.should == 3
    instance.d.should == 4
  end

  it "looks up configuration settings with fallback" do
    profile_role_config = {:a => 1}
    role_config = {:a => 2, :b => 2}

    instance = Instance.new_for_service(:ec2, 'instance1', nil, nil, role_config, profile_role_config, {})

    instance.config(:a, false).should == 1
    instance.config(:b, false).should == 2
  end

  it "fails when required configuration settings are missing" do
    instance = Instance.new_for_service(:ec2, 'instance1', nil, nil, {}, {}, {})

    instance.config(:a, false).should == nil
    lambda {instance.config(:a, true)}.should raise_exception(ArgumentError, "Missing required config: a")
  end
end
