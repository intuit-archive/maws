class Instance
  attr_accessor :name, :role, :connection
  attr_reader :aws_id, :aws_description, :status

  def self.new_for_service(service, *args)
    klass = case service.to_sym
    when :ec2 : Instance::EC2
    when :rds : Instance::RDS
    else raise "No such service: #{service}"
    end

    klass.new(*args)
  end

  def initialize(n,r,s)
    @name, @role, @status = n,r,s
    @aws_id = nil
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
    col_width = 20
    name_padding = " " * (20-@name.length)
    # role_padding = " " * (20-@role.name.length)
    # status_padding = " " * (20-name.length)

    sync_column = synced? ? "S    " : "     "
    sync_column + @name.to_s + name_padding + display_status
  end

  def display_status
    case @status
    when 'unknown' : '?'
    else @status
    end
  end

  def self.for_role(role_name)
    all.select {|i| i.role.name == role_name}
  end

  def self.all
    @all ||= []
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
