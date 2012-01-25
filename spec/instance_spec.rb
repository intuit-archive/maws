require 'spec/spec_helper'
require 'maws/connection'
require 'maws/instance'

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

  describe "with remote configurations" do
    before do
      Instance.instance_eval {@@configurations_cache = nil}

      @profile_role_config = mash({
        :configurations => [
          {:name => 'c1', :command => 'commandP-1'},
          {:name => 'c2', :command => 'commandP-2'},
          {:name => 'c3', :command => 'commandP-3'},
          {:name => 's1', :command_set => %w(1 2 3)},
          {:name => 't1',
                  :location => "locationP-1",
                  :template_params => {:t1p1 => 'paramP-11', :t1p2 => 'paramP-12'}},
          {:name => 't2', :template => 'templateP-2.erb',
                  :template_params => {:t2p2 => 'paramP-22'}}
          ]
      })

      @role_config = mash({
        :name => 'roleX',
        :configurations => [
          {:name => 'c1', :command => 'commandR-1'},
          {:name => 'c4', :command => 'commandR-4'},
          {:name => 's1', :command_set => %w(0 1 2)},
          {:name => 't1', :template => 'templateR-1.erb',
                  :location => "locationR-1",
                  :template_params => {:t1p2 => 'paramR-12'}},
          {:name => 't2', :template => 'templateR-2.erb',
                  :location => 'locationR-2',
                  :template_params => {:t2p1 => 'paramR-21'}}
          ]
      })
    end


    it "looks up remote configurations from role definition" do
      @role_config.name = "role1"
      instance = Instance.new_for_service(:ec2, 'instance1', nil, nil, @role_config, mash, mash)

      instance.configurations.count.should == 5

      instance.configurations[0].should == @role_config.configurations[0]
      instance.configurations[1].should == @role_config.configurations[1]
      instance.configurations[2].should == @role_config.configurations[2]
      instance.configurations[3].should == @role_config.configurations[3]
      instance.configurations[4].should == @role_config.configurations[4]
    end

    it "looks up remote configurations from profile definition" do
      instance = Instance.new_for_service(:ec2, 'instance1', nil, nil, mash, @profile_role_config, mash)

      instance.configurations.count.should == 6

      instance.configurations[0].should == @profile_role_config.configurations[0]
      instance.configurations[1].should == @profile_role_config.configurations[1]
      instance.configurations[2].should == @profile_role_config.configurations[2]
      instance.configurations[3].should == @profile_role_config.configurations[3]
      instance.configurations[4].should == @profile_role_config.configurations[4]
      instance.configurations[5].should == @profile_role_config.configurations[5]
    end

    it "caches configurations for role" do
      instance1 = Instance.new_for_service(:ec2, 'instance1', nil, nil, @role_config, mash, mash)
      instance2 = Instance.new_for_service(:ec2, 'instance1', nil, nil, @role_config, mash, mash)


      instance1.configurations.count.should == 5

      instance2.should_not_receive(:merge_configurations)
      instance2.configurations.count.should == 5
    end

    it "merges remote configurations from profile and role definitions (profile overrides role)" do
      instance = Instance.new_for_service(:ec2, 'instance1', nil, nil, @role_config, @profile_role_config, mash)

      instance.configurations.count.should == 7

      instance.configurations[0].should == @profile_role_config.configurations[0]
      instance.configurations[1].should == @role_config.configurations[1]
      instance.configurations[2].should == @profile_role_config.configurations[3]

      instance.configurations[3].should == mash({:name => 't1', :template => 'templateR-1.erb',
                            :location => "locationP-1", :template_params => {:t1p1 => 'paramP-11', :t1p2 => 'paramP-12'}})

      instance.configurations[4].should == mash({:name => 't2', :template => 'templateP-2.erb',
                            :location => 'locationR-2', :template_params => {:t2p1 => 'paramR-21', :t2p2 => 'paramP-22'}})

      instance.configurations[5].should == @profile_role_config.configurations[1]
      instance.configurations[6].should == @profile_role_config.configurations[2]
    end
  end
end
