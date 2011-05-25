require 'rubygems'
require 'AWS'

ACCESS_KEY_ID = "AKIAIQ7UIX3FGYYFTBOA"
SECRET_ACCESS_KEY = "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"

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
    "Instance ID: #{@instance_id}\n" +
    "Public DNS: #{@dns_name}\n" +
    "Private DNS: #{@private_dns_name}\n" +
    "Private IP: #{@private_ip}\n" +
    "Instance Type: #{@instance_type}\n" +
    "Group: #{@group}\n" +
    "State: #{@state}\n"
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
      instances_to_stop << i.instance_id
    end
    @ec2.stop_instances({:instance_id => instances_to_stop})
  end
  
  def start_instances(instances)
    instances_to_start = Array.new
    
    instances.each do |i|
      instances_to_start << i.instance_id
    end
    @ec2.start_instances({:instance_id => instances_to_start})
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
    apps.each do |a|
      puts "BalancerMember http://#{a.private_dns_name}:8080"
    end
  end

  def self.print_ssh_commands(instances)
    instances.each do |instance|
      puts "ssh -i #{instance.keyname}.pem root@#{instance.dns_name}"
    end
  end
  
  private
  
  def get_instance_blob
    @ec2.describe_instances
  end
  
end


###############
# Script Start
###############
ecc = LcAws.new
instances = ecc.get_instances
instances.each_with_index do |i, index|
  puts "***INSTANCE #{index}***"
  puts i.to_s
  puts "***********************"
end

puts "WEB PROXY CONFIG"
ecc.print_proxy_members(instances)

puts "SSH commands (apps)"
LcAws.print_ssh_commands(ecc.get_app_instances(instances))

puts "SSH commands (loadgen)"
LcAws.print_ssh_commands(ecc.get_loadgen_instances(instances))

#puts "Stopping all app servers..."
#ecc.stop_app_servers
#puts "Done."

#puts "Stopping all loadgen servers..."
#ecc.stop_loadgen_servers
#puts "Done."
