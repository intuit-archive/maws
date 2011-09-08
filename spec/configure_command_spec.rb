require 'spec/spec_helper'
require 'lib/aws_connection'
require 'lib/command'
require 'lib/commands/configure'


describe "configure command" do
  it "defines template temporary output path" do
    Configure::TEMPLATE_OUTPUT_DIR.should == File.expand_path(SPEC_BASE_PATH + "/tmp")
  end

  it "adds command line options" do
    command = Configure.new(nil, nil)
    parser = mock('parser')

    parser.should_receive(:opt).once.
      with(:dump, "Dump config files before uploading them", :type => :flag, :default => false)

    parser.should_receive(:opt).once.
      with(:command, "Command to run remotely (either name or a string)", :type => :string, :default => "")

    parser.should_receive(:opt).once.
      with(:login_name, "The SSH login name", :short => "-l", :type => :string, :default => "root")

    parser.should_receive(:opt).once.
      with(:identity_file, "The SSH identity file", :short => "-i", :type => :string)

    command.add_specific_options(parser)
  end

  it "works only on specified and running instances" do
    i1 = Instance::EC2.new('i1', nil, nil, empty_config, empty_config, empty_config)
    i2 = Instance::EC2.new('i2', 'running', nil, empty_config, empty_config, empty_config)
    i3 = Instance::EC2.new('i3', 'running', nil, empty_config, empty_config, empty_config)

    command = Configure.new(nil, nil)
    command.options = mock('options', :command => "fakecommand")

    ssh1 = mock('ssh-1')

    command.should_receive(:specified_instances).once.and_return([i1,i2])
    command.should_receive(:ssh_connect_to).once.with(i2).and_return(ssh1)
    ssh1.should_receive(:exec!).once.with("fakecommand")
    command.should_receive(:ssh_disconnect).once.with(ssh1, i2).and_return(nil)

    command.run!
  end

  it "does nothing if no configurations are defined in profile or command line" do
    i1 = Instance::EC2.new('i1', 'running', nil, empty_config, empty_config, empty_config)

    command = Configure.new(nil, nil)
    command.options = mock('options', :command => "")

    command.should_receive(:specified_instances).once.and_return([i1])
    command.should_not_receive(:ssh_connect_to)

    command.run!
  end

  it "connects and disconects for each instance" do
    i1 = Instance::EC2.new('i1', 'running', nil, empty_config, empty_config, empty_config)
    i2 = Instance::EC2.new('i2', 'running', nil, empty_config, empty_config, empty_config)

    command = Configure.new(nil, nil)
    command.options = mock('options', :command => "fakecommand")

    ssh1 = mock("ssh1", :exec! => nil)
    ssh2 = mock("ssh2", :exec! => nil)

    command.should_receive(:specified_instances).once.and_return([i1,i2])

    command.should_receive(:ssh_connect_to).once.with(i1).and_return(ssh1)
    command.should_receive(:ssh_connect_to).once.with(i2).and_return(ssh2)

    command.should_receive(:ssh_disconnect).once.with(ssh1, i1).and_return(nil)
    command.should_receive(:ssh_disconnect).once.with(ssh2, i2).and_return(nil)

    command.run!
  end

  it "connects using correct host, username and keypair settings" do
    i1 = Instance::EC2.new('i1', 'running', nil, empty_config, empty_config, empty_config)
    i1.stub!(:dns_name).and_return("i1.amazonaws.com")
    i1.stub!(:keypair).and_return("i1kp")

    command = Configure.new(nil, nil)
    command.options = mock('options', :command => "fakecommand", :login_name => "root", :identity_file => nil)
    command.should_receive(:specified_instances).once.and_return([i1])

    identity_file = "#{KEYPAIRS_PATH}/i1kp.pem"
    File.should_receive(:exists?).once.with(identity_file).and_return(true)

    ssh = mock('ssh')
    Net::SSH.should_receive(:start).once.
      with('i1.amazonaws.com', 'root',
            {:keys => [identity_file],
             :verbose => :warn,
             :auth_methods => ['publickey']}).and_return(ssh)
    ssh.should_receive(:exec!).once.with("fakecommand")
    ssh.should_receive(:close).once

    command.run!
  end

  it "processes a list of configuration steps" do
    c1 = mash({:name => 'c1', :command => 'ls -l'})
    c2 = mash({:name => 'c2', :command => 'ls -a'})
    profile_role_config = mash({:configurations => [c1,c2]})
    i1 = Instance::EC2.new('i1', 'running', nil, empty_config, profile_role_config, empty_config)

    command = Configure.new(nil, nil)
    command.options = mock('options', :command => "")
    command.should_receive(:specified_instances).once.and_return([i1])

    ssh1 = mock('ssh1')

    command.should_receive(:ssh_connect_to).once.with(i1).and_return(ssh1)
    command.should_receive(:ssh_disconnect).once.with(ssh1, i1).and_return(nil)

    ssh1.should_receive(:exec!).once.with('ls -l')
    ssh1.should_receive(:exec!).once.with('ls -a')

    command.run!
  end


  it "queues a named remote command for execution" do
    c1 = mash({:name => 'c1', :command => 'ls -l'})
    c2 = mash({:name => 'c2', :command => 'ls -a'})
    profile_role_config = mash({:configurations => [c1,c2]})
    i1 = Instance::EC2.new('i1', 'running', nil, empty_config, profile_role_config, empty_config)

    command = Configure.new(nil, nil)
    command.options = mock('options', :command => "c2")
    command.should_receive(:specified_instances).once.and_return([i1])

    command.should_receive(:queue_remote_command).once.with(i1, 'c2', 'ls -a')

    command.run!
  end

  it "queue a template from a named command" do
    template_config = mash({:name => 'database', :template => 'database.yml'})
    profile_role_config = mash({:configurations => [template_config]})
    i1 = Instance::EC2.new('i1', 'running', nil, empty_config, profile_role_config, empty_config)

    command = Configure.new(nil, nil)
    command.options = mock('options', :command => "database")
    command.should_receive(:specified_instances).once.and_return([i1])

    command.should_receive(:generate_and_queue_upload_template).with(i1, template_config).once

    command.run!
  end

  it "executes an arbitrary remote command from command line" do
    c1 = mash({:name => 'c1', :command => 'ls -l'})
    profile_role_config = mash({:configurations => [c1]})
    i1 = Instance::EC2.new('i1', 'running', nil, empty_config, profile_role_config, empty_config)

    command = Configure.new(nil, nil)
    command.options = mock('options', :command => "ls -a")
    command.should_receive(:specified_instances).once.and_return([i1])

    ssh1 = mock('ssh1')

    command.should_receive(:ssh_connect_to).once.with(i1).and_return(ssh1)
    command.should_receive(:ssh_disconnect).once.with(ssh1, i1).and_return(nil)
    ssh1.should_receive(:exec!).once.with('ls -a')

    command.run!
   end

  describe "for templates" do
    pending "generates config file from template"
    pending "uploads config file"
    describe "when resolving parameters" do
      pending "parsers 'self' paramter"
      pending "selects all instances that have a specific role with 'select_many' option"
      pending "selects (in round-robin order) chunks of all instances that have a specific role with 'select_many' option"
      pending "selects a single instance (in round-robin order) that has a specific role with 'selec_one' option"
    end
  end

  def empty_config
    mash({})
  end
end
