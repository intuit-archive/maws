class Instance
  attr_accessor :name, :role, :profile_for_role_config, :connection
  attr_reader :aws_id, :aws_description, :status

  def self.new_for_service(service, *args)
    klass = case service.to_sym
    when :ec2 : Instance::EC2
    when :rds : Instance::RDS
    else raise "No such service: #{service}"
    end

    klass.new(*args)
  end

  def initialize(name, role, availability_zone, profile_for_role, status)
    @name, @role, @profile_for_role_config, @availability_zone, @status = name, role, profile_for_role, availability_zone, status
    @aws_id = nil
  end

  def sync
    description = @connection.description_for_name(name)
    if description
      self.aws_description = description
    else
      @status = 'non-existant'
    end
  end

  def synced?
    !@aws_id.nil?
  end

  def terminated?
    status == 'terminated'
  end

  def exists_on_aws?
    synced? && !terminated?
  end

  def aws_description=(description)
    # description is a hash, see bottom of the file for each instance class for examples
    rise "not implemented"
  end
end

require 'lib/instance/ec2'
require 'lib/instance/rds'


# build all
# build non-existing
# check version by hash ?
# object for each instance?
# objects start, stop, sync themselves?
# tool knows no state
# establish state