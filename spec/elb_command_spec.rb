require 'spec/spec_helper'
require 'lib/aws_connection'
require 'lib/command'
require 'lib/elb_command'

describe "ElbCommand" do
  it "partitions specified instances into ELB and non-ELB sets" do
    instances = bunch_of_instances

    elbs = [instances[2], instances[3], instances[5]];
    ec2s = [instances[0], instances[1], instances[4]]
    ec2s.each {|i| i.stub!(:alive?).and_return(true)}

    command = ElbCommand.new(nil,nil)
    command.should_receive(:specified_instances).and_return(instances)

    command.partition_elbs_and_instances.should == [elbs,ec2s]
  end

  it "does not partition specified instances when no ELBs are specified" do
    instances = bunch_of_instances.reject {|i| i.is_a? Instance::ELB}
    command = ElbCommand.new(nil,nil)
    command.should_receive(:specified_instances).and_return(instances)

    command.partition_elbs_and_instances.should be_nil
  end

  it "does not partition specified instances when no EC2s are specified" do
    instances = bunch_of_instances.reject {|i| i.is_a? Instance::EC2}
    command = ElbCommand.new(nil,nil)
    command.should_receive(:specified_instances).and_return(instances)

    command.partition_elbs_and_instances.should be_nil
  end

  it "does not partition specified instances when no EC2s are alive" do
    instances = bunch_of_instances

    elbs = [instances[2], instances[3], instances[5]];
    ec2s = [instances[0], instances[1], instances[4]]
    ec2s.each {|i| i.stub!(:alive?).and_return(false)}

    command = ElbCommand.new(nil,nil)
    command.should_receive(:specified_instances).and_return(instances)

    command.partition_elbs_and_instances.should be_nil
  end

  def bunch_of_instances
     [
      Instance.new_for_service(:ec2, 'web1', nil, nil, {}, {}, {}),
      Instance.new_for_service(:ec2, 'web2', nil, nil, {}, {}, {}),
      Instance.new_for_service(:elb, 'elb1', nil, nil, {}, {}, {}),
      Instance.new_for_service(:elb, 'elb2', nil, nil, {}, {}, {}),
      Instance.new_for_service(:ec2, 'web3', nil, nil, {}, {}, {}),
      Instance.new_for_service(:elb, 'elb3', nil, nil, {}, {}, {}),
    ]
  end

end