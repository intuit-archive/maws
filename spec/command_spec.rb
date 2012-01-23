require 'spec/spec_helper'
require 'lib/aws_connection'
require 'lib/command'

describe "Command" do
  it "defines generic command line options" do
    command = Command.new(nil, {'role1' => {}, 'role2' => {}})
    command.default_region = 'us-east-1'
    command.default_zone = 'b'
    parser = mock('command line parser')

    parser.should_receive(:opt).once.with(:roles, "List of roles (available: role1, role2)", :type => :strings)
    parser.should_receive(:opt).once.with(:names, "Names of machines", :type => :strings)
    parser.should_receive(:opt).once.with(:all, "All roles", :short => '-A', :type => :flag)
    parser.should_receive(:opt).once.with(:region, "Region", :type=> :string, :short => '-R', :default => 'us-east-1')
    parser.should_receive(:opt).once.with(:zone, "Zone", :type=> :string, :short => '-Z', :default => 'b')

    command.add_generic_options(parser)
  end

  it "list command line specified instances" do
    profile = mock('profile')
    profile.should_receive(:specified_instances).and_return(%w(i1 i2))

    Command.new(profile,nil).specified_instances.should == %w(i1 i2)
  end

  describe "when syncing" do
    before do
      @i1 = mock('instance 1')
      @i2 = mock('instance 2')

      @i1.stub!(:connection=)
      @i2.stub!(:connection=)

      @i1.should_receive(:sync!)
      @i2.should_receive(:sync!)

      @profile = mock('profile')
    end

    it "syncs all defined instances by default" do
      @profile.should_receive(:defined_instances).and_return([@i1,@i2])
      @profile.should_not_receive(:specified_instances)

      Command.new(@profile, nil).sync_profile_instances
    end

    it "overrides default syncing instances" do
      command = Command.new(@profile,nil)

      command.should_receive(:default_sync_instances).and_return([@i1,@i2])
      @profile.should_not_receive(:defined_instances)

      command.sync_profile_instances
    end

  end

end
