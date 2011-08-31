class Instance
  attr_accessor :name, :role, :connection, :profile, :options
  attr_reader :aws_id, :aws_description, :status, :role_config, :profile_role_config

  def self.new_for_service(service, *args)
    klass = case service.to_sym
    when :ec2 : Instance::EC2
    when :rds : Instance::RDS
    when :elb : Instance::ELB
    else raise "No such service: #{service}"
    end

    klass.new(*args)
  end

  def initialize(name, status, profile, role_config, profile_role_config, command_options)
    @name = name
    @status = status
    @profile = profile

    @role_config = role_config
    @profile_role_config = profile_role_config
    @command_options = command_options

    @aws_id = nil
    @aws_description = {}
  end

  def sync
    description = @connection.description_for_name(name, @role_config.service)
    if description
      self.aws_description = description
    else
      @aws_description = {}
      @aws_id = nil
      @status = 'n/a'
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

  def to_s
    "#{name}   #{status}    #{@aws_id}"
  end

  def inspect
    "<Instance #{to_s}>"
  end

  def role_name
    @role_config.name
  end

  def has_approximate_status?(status)
    if status == "n/a" or status == "terminated"
      terminated? || !exists_on_aws?
    else
      status == @status
    end
  end

  def method_missing(method_name, *args, &block)
    @role_config[method_name] ||
    @profile_role_config[method_name] ||
    @aws_description[method_name] ||
    @command_options[method_name]
  end

  def config(key, required=false)
    if required && @profile_role_config[key].nil? && @role_config[key].nil?
      raise ArgumentError.new("Missing required config: #{key}")
    end

    @profile_role_config[key] || @role_config[key]
  end
end

require 'lib/instance/ec2'
require 'lib/instance/rds'
require 'lib/instance/elb'


# build all
# build non-existing
# check version by hash ?
# object for each instance?
# objects start, stop, sync themselves?
# tool knows no state
# establish state
