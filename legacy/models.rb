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
    @tags = data['tagSet']['item'] unless data['tagSet'].nil?
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
    unless @tags.nil?
      @tags.each do |t|
        return t['value'] if t['key'] == 'Name'
      end
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
