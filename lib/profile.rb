require 'lib/instance'

class ProfileForRole
  attr_reader :config

  def initialize(profile, role_profile_config)
    @profile = profile
    @config = role_profile_config
  end

  def select_one_of_role(name)
    @profile.instances_for_role(name).first
  end
end

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
        unless role_profile.scope == 'region'
          name << options.zone
        end
        instance = Instance.new_for_service(role.service, name, 'unknown', role, self, options)
        @all_instances << instance
      end
    end
  end

  def instance_with_name(name)
    @name_grouped_instances ||= @all_instances.group_by {|i| i.name}
    @name_grouped_instances[name].first
  end

  def instances_for_role(name)
    @role_grouped_instances ||= @all_instances.group_by {|i| i.role.name}
    @role_grouped_instances[name]
  end

  def profile_for_role(name)
    @roles_profiles ||= {}
    @roles_profiles[name] ||= ProfileForRole.new(self, config[name])
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