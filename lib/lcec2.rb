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

class LcAws

  def initialize
    @ec2 = AWS::EC2::Base.new(:access_key_id => ACCESS_KEY_ID, :secret_access_key => SECRET_ACCESS_KEY)
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
  
  def get_app_instances(instances = nil)
    get_instances_by_name("app", instances)
  end

  def get_loadgen_instances(instances = nil)
    get_instances_by_name("gen", instances)
  end

  def get_instances_by_name(name_filter, instances = nil)
    all_instances = instances
    all_instances = get_instances if all_instances.nil?
    filtered_instances = Array.new
    all_instances.each do |instance|
      # check if the name matches
      filtered_instances << instance if instance.name.include? name_filter
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
      puts "Stopping instances: " + instances_to_start.inspect
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
      puts "ssh -i #{instance.keyname}.pem root@#{instance.dns_name}"  if instance.running?
    end
  end
  
  private
  
  def get_instance_blob
    @ec2.describe_instances
  end
  
end

