require 'rubygems'
require 'AWS'


#Set the aws keys in your env.
ACCESS_KEY_ID = ENV["AWS_ACCESS_KEY_ID"]
SECRET_ACCESS_KEY = ENV["AWS_SECRET_ACCESS_KEY"] 

class Ec2Instance
  attr_accessor :instance_id,
                :dns_name,
                :private_dns_name,
                :private_ip,
                :instance_type,
                :monitoring,
                :state,
                :group,
                :keyname,
                :tags,
                :raw_data
  
  def initialize(data)
    #puts data.keys
    @raw_data = data
    @instance_id = data['instanceId']
    @dns_name = data['dnsName']
    @private_dns_name = data['privateDnsName']
    @private_ip = data['privateIpAddress']
    @instance_type = data['instanceType']
    @monitoring = data['monitoring']
    @state = data['instanceState']['name']
    @keyname = data['keyName']
    @tags = data['tagSet']['item']
  end
  
  def to_s
    str = 
    "Name: #{name}\n" +
    "State: #{@state}\n" +
    "Instance ID: #{@instance_id}\n" +
    "Public DNS: #{@dns_name}\n" +
    "Private DNS: #{@private_dns_name}\n" +
    "Private IP: #{@private_ip}\n" +
    "Instance Type: #{@instance_type}\n" +
    "Group: #{@group}\n"
    @tags.each do |t|
      str += "tags: #{t["key"]} = #{t["value"]}\n"
    end
    str
  end
  
  def name
    @tags.each do |t|
      return t['value'] if t['key'] == 'Name'
    end
    ""
  end
  
  def running?
    return @state == "running"
  end
  
  def stopped?
     return @state == "stopped"
   end
  
end

class RdsInstance
  attr_accessor :name,
                :endpoint_address,
                :endpoint_port,
                :parameter_group,
                :storage,
                :instance_class,
                :state
                
  def initialize(data)
    #=> {"Engine"=>"mysql5.5", "PendingModifiedValues"=>nil, "BackupRetentionPeriod"=>"0", "DBInstanceStatus"=>"modifying", 
    #    "DBParameterGroups"=>{"DBParameterGroup"=>{"ParameterApplyStatus"=>"pending-reboot", "DBParameterGroupName"=>"ttlc-mysql-5-5"}}, 
    #    "DBInstanceIdentifier"=>"db1", "Endpoint"=>{"Port"=>"3306", "Address"=>"db1.cckovstulx2c.us-east-1.rds.amazonaws.com"}, 
    #    "DBSecurityGroups"=>{"DBSecurityGroup"=>{"Status"=>"active", "DBSecurityGroupName"=>"default"}}, "PreferredBackupWindow"=>"07:30-08:00", 
    #    "DBName"=>"cia_prod", "PreferredMaintenanceWindow"=>"fri:03:00-fri:03:30", "AvailabilityZone"=>"us-east-1c", 
    #    "InstanceCreateTime"=>"2011-05-17T21:32:22.692Z", "AllocatedStorage"=>"300", "DBInstanceClass"=>"db.m1.large", "MasterUsername"=>"dbuser"} 
        
    @name = data['DBInstanceIdentifier']
    @endpoint_address = data['Endpoint']['Address'] if data['Endpoint']
    @endpoint_port = data['Endpoint']['Port'] if data['Endpoint']
    @parameter_group = data['DBParameterGroups']['DBParameterGroup']['DBParameterGroupName']
    @storage = data['AllocatedStorage'].to_i if data['AllocatedStorage']
    @instance_class = data['DBInstanceClass']
    @state = data['DBInstanceStatus']
    
  end
  
  def to_s
    str = 
    "Name: #{@name}\n" +
    "State: #{@state}\n" +
    "Instance Type: #{@instance_class}\n" +
    "Storage: #{@storage}GB\n" +
    "Parameter Group: #{@parameter_group}\n" +
    "Endpoint: #{@endpoint_address}\n" +
    "Port: #{@endpoint_port}\n"
  end
end

class LcAws
  attr_accessor :ec2, :rds
  
  def initialize
    @ec2 = AWS::EC2::Base.new(:access_key_id => ACCESS_KEY_ID, :secret_access_key => SECRET_ACCESS_KEY)
    @rds = AWS::RDS::Base.new(:access_key_id => ACCESS_KEY_ID, :secret_access_key => SECRET_ACCESS_KEY)
  end

  #
  # instance definitions
  #
  def get_instances
    all_instances = Array.new
    instance_data = get_instance_blob
    
    items = instance_data["reservationSet"]["item"]
    items.each do |i|
      new_instance = nil
      instances = i["instancesSet"]["item"]
      instances.each do |instance|
        new_instance = Ec2Instance.new(instance)
        all_instances << new_instance

        groups = i["groupSet"]["item"]
        new_instance.group = groups[0]['groupId']
      end
    end   
    all_instances 
  end
  
  def get_rds_instances
    all_instances = Array.new
    db_instances = @rds.describe_db_instances["DescribeDBInstancesResult"]["DBInstances"]["DBInstance"]
    db_instances.each do |db_data|
      new_instance = RdsInstance.new(db_data)
      all_instances << new_instance
    end
    all_instances
  end
  
  def get_app_instances(instances = nil, state = nil)
    get_instances_by_name("app", instances, state)
  end

  def get_loadgen_instances(instances = nil, state = nil)
    get_instances_by_name("gen", instances, state)
  end

  def get_web_instances(instances = nil, state = nil)
    get_instances_by_name("web", instances, state)
  end

  def get_instances_by_name(name_filter, instances = nil, state = nil)
    all_instances = instances
    all_instances = get_instances if all_instances.nil?
    filtered_instances = Array.new
    all_instances.each do |instance|
      # check if the name matches AND the state matches the filter provided
      if instance.name.include?(name_filter) && (state.nil? || instance.state == state)
        filtered_instances << instance 
      end
    end
    filtered_instances
  end

  #
  # stopping / starting
  #
  def stop_instances(instances)
    instances_to_stop = Array.new
    
    instances.each do |i|
      instances_to_stop << i.instance_id if i.running?
    end
    if instances_to_stop.size > 0
      puts "Stopping instances: " + instances_to_stop.inspect
      @ec2.stop_instances({:instance_id => instances_to_stop})
    else
      puts "No instances to stop"
    end
  end
  
  def start_instances(instances)
    instances_to_start = Array.new
    
    instances.each do |i|
      instances_to_start << i.instance_id if i.stopped?
    end
    if instances_to_start.size > 0
      puts "Starting instances: " + instances_to_start.inspect
      @ec2.start_instances({:instance_id => instances_to_start})
    else
      puts "No instances to start"
    end
  end
  
  def start_app_servers
    start_instances(get_app_instances)
  end

  def stop_app_servers
    stop_instances(get_app_instances)
  end
  
  def start_loadgen_servers
    start_instances(get_loadgen_instances)
  end

  def stop_loadgen_servers
    stop_instances(get_loadgen_instances)
  end
  
  #
  # printing helpful commands
  #
  def print_proxy_members(instances = nil)
    apps = get_app_instances(instances)
    apps.each do |instance|
      puts "# #{instance.name}" if instance.running?
      puts "BalancerMember http://#{instance.private_dns_name}:8080" if instance.running?
    end
  end

  def self.print_ssh_commands(instances)
    instances.each do |instance|
      if instance.keyname == ""
        puts "ssh -i intuit-baseline.pem ea@#{instance.dns_name}"  if instance.running?
      else
        puts "ssh -i #{instance.keyname}.pem root@#{instance.dns_name}"  if instance.running?
      end
    end
  end
  
  private
  
  def get_instance_blob
    @ec2.describe_instances
  end
  
end

