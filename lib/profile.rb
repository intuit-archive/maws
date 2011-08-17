require 'lib/instance'

class Profile
  RESERVED_ROLE_NAMES = %w(roles lanes name)
  attr_reader :config, :roles

  def initialize(config, roles)
    @config = config
    @roles = roles

    build_instance_objects
  end

  def build_instance_objects
    defined_roles.each do |role_name|
      role = @roles[role_name]
      role_profile = @config[role_name]
      role_profile.count.times do |i|
        name = "%s-%s-%d" % [self.name,role_name,i+1]
        Instance.all << Instance.new_for_service(role.service,name,role,'unknown')
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