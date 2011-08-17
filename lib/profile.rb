require 'lib/instance'

class Profile
  RESERVED_ROLE_NAMES = %w(roles lanes name)
  attr_reader :config, :roles, :all_instances
  attr_accessor :options

  def initialize(config, roles)
    @config = config
    @roles = roles
  end

  def build_instance_objects
    @all_instances = []
    defined_roles.each do |role_name|
      role = @roles[role_name]
      role_profile = @config[role_name]
      role_profile.count.times do |i|
        name = "%s-%s-%d" % [self.name,role_name,i+1]
        @all_instances << Instance.new_for_service(role.service, name, role,
                                              @options.availability_zone, @config[role_name],
                                              'unknown')
      end
    end
  end

  def name
    @config.name
  end

  def missing_roles
    available_roles = @roles.keys
    missing_roles = defined_roles - available_roles
  end

  def defined_roles
    @config.keys - RESERVED_ROLE_NAMES
  end

end