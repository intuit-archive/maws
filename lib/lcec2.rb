require 'rubygems'
require 'AWS'
require './lib/models'

#Set the aws keys in your env.
ACCESS_KEY_ID = ENV["AWS_ACCESS_KEY_ID"]
SECRET_ACCESS_KEY = ENV["AWS_SECRET_ACCESS_KEY"] 

# default AMI's to use if no other AMI is specified
# - these should be the AMI's that are the current standard for each server type
DEFAULT_WEB_AMI = "ami-98d014f1"
DEFAULT_APP_AMI = "ami-93e720fa"
DEFAULT_SERVICE_AMI = DEFAULT_APP_AMI # service hosts get the same image as an app host for now
DEFAULT_SEARCH_AMI = DEFAULT_APP_AMI # service hosts get the same image as an app host for now
DEFAULT_QUEUE_AMI = "ami-97e720fe"
DEFAULT_CACHE_AMI = "ami-67cc0b0e"
DEFAULT_LOADGEN_AMI = "ami-e130f488"

DEFAULT_INSTANCE_TYPE = "m1.xlarge"
DEFAULT_WEB_INSTANCE_TYPE = DEFAULT_INSTANCE_TYPE
DEFAULT_APP_INSTANCE_TYPE = "c1.xlarge"
DEFAULT_SERVICE_INSTANCE_TYPE = DEFAULT_INSTANCE_TYPE
DEFAULT_SEARCH_INSTANCE_TYPE = "m2.2xlarge"
DEFAULT_QUEUE_INSTANCE_TYPE = DEFAULT_INSTANCE_TYPE
DEFAULT_CACHE_INSTANCE_TYPE = DEFAULT_INSTANCE_TYPE
DEFAULT_LOADGEN_INSTANCE_TYPE = "m2.4xlarge"

class LcAws
  attr_accessor :ec2, :rds
  
  def initialize(region = "us-east-1")
    ec2_server = "ec2.us-east-1.amazonaws.com" if region == "us-east-1"
    ec2_server = "ec2.us-west-1.amazonaws.com" if region == "us-west-1"
    rds_server = "rds.us-east-1.amazonaws.com" if region == "us-east-1"
    rds_server = "rds.us-west-1.amazonaws.com" if region == "us-west-1"
    
    @ec2 = AWS::EC2::Base.new(:access_key_id => ACCESS_KEY_ID, :secret_access_key => SECRET_ACCESS_KEY, :server => ec2_server)
    @rds = AWS::RDS::Base.new(:access_key_id => ACCESS_KEY_ID, :secret_access_key => SECRET_ACCESS_KEY, :server => rds_server)
  end

  #
  # instance definitions
  #
  def get_instances(state = nil)
    all_instances = Array.new
    instance_data = get_instance_blob
    if instance_data != nil
      items = instance_data["reservationSet"]["item"]
      items.each do |i|
        new_instance = nil
        instances = i["instancesSet"]["item"]
        instances.each do |instance|
          new_instance = Ec2Instance.new(instance)
          all_instances << new_instance if (state.nil? || new_instance.state == state)

          groups = i["groupSet"]["item"]
          new_instance.group = groups[0]['groupId']
        end
      end   
    end
    all_instances 
  end
  
  def get_instances_by_name(name_filter, instances = nil, state = nil)
    all_instances = instances
    all_instances = get_instances if all_instances.nil?
    filtered_instances = Array.new
    all_instances.each do |instance|
      # check if the name matches AND the state matches the filter provided
      if !instance.name.nil? && instance.name.include?(name_filter) && (state.nil? || instance.state == state)
        filtered_instances << instance 
      end
    end
    filtered_instances
  end
  
  def get_rds_instances
    all_instances = Array.new
    db_instances = @rds.describe_db_instances["DescribeDBInstancesResult"]["DBInstances"]["DBInstance"]
    if db_instances != nil
      db_instances.each do |db_data|
        new_instance = RdsInstance.new(db_data)
        all_instances << new_instance
      end
    end
    all_instances
  end
 
  def get_rds_instances_by_name(name_filter, instances = nil)
    all_instances = instances
    all_instances = get_rds_instances if all_instances.nil?
    filtered_instances = Array.new
    all_instances.each do |instance|
      # check if the name matches
      if !instance.name.nil? and instance.name.include?(name_filter) 
        filtered_instances << instance
      else  
        puts instance.name.to_s
      end
    end
    filtered_instances
  end

 
  def get_app_instances(instances = nil, state = nil)
    get_instances_by_name("app", instances, state)
  end

  def get_loadgen_instances(instances = nil, state = nil)
    get_instances_by_name("loadgen", instances, state)
  end

  def get_web_instances(instances = nil, state = nil)
    get_instances_by_name("web", instances, state)
  end

  def get_service_instances(instances = nil, state = nil)
    get_instances_by_name("service", instances, state)
  end
  
  def get_cache_instances(instances = nil, state = nil)
    get_instances_by_name("cache", instances, state)
  end
  
  def get_queue_instances(instances = nil, state = nil)
    get_instances_by_name("queue", instances, state)
  end
  
  def get_search_instances(instances = nil, state = nil)
    get_instances_by_name("search", instances, state)
  end

  def get_app_layer_instances(instance = nil, state = "running")
   app =  get_instances_by_name("app", instance, state)
   service = get_instances_by_name("service", instance, state)
   search = get_instances_by_name("search", instance, state)
   servers = app | service | search
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
  
  #
  # starting / stopping of specific types
  #
  
  def start_app_servers
    start_instances(get_app_instances)
  end

  def stop_app_servers
    stop_instances(get_app_instances)
  end
  
  def start_web_servers
    start_instances(get_web_instances)
  end

  def stop_web_servers
    stop_instances(get_web_instances)
  end
  
  def start_loadgen_servers
    start_instances(get_loadgen_instances)
  end

  def stop_loadgen_servers
    stop_instances(get_loadgen_instances)
  end
  
  def start_service_servers
    start_instances(get_service_instances)
  end
  
  def stop_service_servers
    stop_instances(get_service_instaces)
  end
  
  def start_search_servers
    start_instances(get_search_instances)
  end
  
  def stop_search_servers
    stop_instances(get_search_instances)
  end
  
  def start_cache_servers
    start_instances(get_cache_instances)
  end
  
  def stop_cache_servers
    stop_instances(get_cache_instances)
  end
  
  def start_queue_servers
    start_instances(get_queue_instances)
  end
  
  def stop_queue_servers
    stop_instances(get_queue_instances)
  end
  
  # 
  # specific instance creation methods
  #
  
  def add_web_instances(num, zone, names, ami = DEFAULT_WEB_AMI)
    opts = {:image_id => ami, 
            :min_count => 1,
            :max_count => 1,
            :security_group => "WebGroup",
            :instance_type => DEFAULT_WEB_INSTANCE_TYPE,
            :availability_zone => zone,
            :monitoring_enabled => true
           }
    add_instances(num,names,'web',opts)
  end
  
  def add_app_instances(num, zone, names, ami = DEFAULT_APP_AMI)
    opts = {:image_id => ami, 
            :min_count => 1,
            :max_count => 1,
            :security_group => "AppGroup",
            :instance_type => DEFAULT_APP_INSTANCE_TYPE,
            :availability_zone => zone,
            :monitoring_enabled => true
           }
    add_instances(num,names,'app',opts)
  end
  
  def add_service_instances(num, zone, names, ami = DEFAULT_SERVICE_AMI)
    opts = {:image_id => ami, 
            :min_count => 1,
            :max_count => 1,
            :security_group => "AppGroup",
            :instance_type => "m1.xlarge",
            :availability_zone => zone,
            :monitoring_enabled => true
           }
    add_instances(num,names,'service',opts)
  end  
  
  def add_search_instances(num, zone, names, ami = DEFAULT_SEARCH_AMI)
    opts = {:image_id => ami, 
            :min_count => 1,
            :max_count => 1,
            :security_group => "AppGroup",
            :instance_type => DEFAULT_SEARCH_INSTANCE_TYPE,
            :availability_zone => zone,
            :monitoring_enabled => true
           }
    add_instances(num,names,'search',opts)
  end
  
  def add_cache_instances(num, zone, names, ami = DEFAULT_CACHE_AMI)
    opts = {:image_id => ami, 
            :min_count => 1,
            :max_count => 1,
            :security_group => "AppGroup",
            :instance_type => DEFAULT_CACHE_INSTANCE_TYPE,
            :availability_zone => zone,
            :monitoring_enabled => true
           }
    add_instances(num,names,'cache',opts)
  end  
  
  def add_queue_instances(num, zone, names, ami = DEFAULT_QUEUE_AMI)
    opts = {:image_id => ami, 
            :min_count => 1,
            :max_count => 1,
            :security_group => "AppGroup",
            :instance_type => DEFAULT_QUEUE_INSTANCE_TYPE,
            :availability_zone => zone,
            :monitoring_enabled => true
           }
    add_instances(num,names,'queue',opts)
  end  

  def add_loadgen_instances(num, zone, names, ami = DEFAULT_LOADGEN_AMI)
    opts = {:image_id => ami, 
            :min_count => 1,
            :max_count => 1,
            :security_group => "LoadGenGroup",
            :instance_type => DEFAULT_LOADGEN_INSTANCE_TYPE,
            :availability_zone => zone,
            :monitoring_enabled => false
           }
    add_instances(num,names,'loadgen',opts)
  end

  
  def show_current_region
    # TODO: implement this somehow...
    puts "Not Yet Implemented... show_current_region"
  end
  
  def get_availability_zones
    zones = @ec2.describe_availability_zones["availabilityZoneInfo"]["item"]
  end
  
  ################
  private
  ################
    
  def get_instance_blob
    @ec2.describe_instances
  end
  
  def add_instances(num, names, role, opts)
     index = 0
     num.times do
       puts "creating #{role} instance #{index}: name = #{names[index]}..."
       response = @ec2.run_instances(opts)
       instance_id = response.instancesSet.item[0].instanceId
       puts " => instance Created: id=#{instance_id}"
       tagged = tag_instance(instance_id,[{'Name' => names[index]}, {'Role' => "#{role}"}])
       puts " => instance Tags Set." if tagged
       puts " => instance Tags NOT Set." if !tagged
       index += 1
     end
   end

   def tag_instance(instance_id, tags)
     tag_opts = {:resource_id => [instance_id], 
                 :tag => tags 
                }
     tagged = false
     
     5.times do
       begin
         @ec2.create_tags(tag_opts)
         tagged = true
         break
       rescue => ex
         puts "Exception creating tags."
         # most likely needs more time to AWS to record the instanceID, so just pause a few secs
         sleep 3
       end
     end
     return tagged
   end
   
end

