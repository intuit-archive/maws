class ProfileLoader
  RESERVED_ROLE_NAMES = %w(roles lanes name zones aliases settings security_rules)

  def initialize(config)
    @config = config
  end

  def load
    # assumes profile file is known to exist already
    load_profile
    load_roles
    load_security_rules

    exit_on_missing_roles
    create_combined
  end

  private

  def load_profile
    profile_name = @config.command_line.profile_name
    profile_path = @config.config.available_profiles[profile_name]

    @config.profile = mash(YAML.load_file(profile_path))
    @config.profile.name = profile_name

    @config.available_roles = @config.profile.keys - RESERVED_ROLE_NAMES
    sort_available_roles_by_appearance_in_profile(profile_path)
  end

  def sort_available_roles_by_appearance_in_profile(profile_path)
    # hacky, but does the job
    profile_text = File.read(profile_path)
    @config.available_roles = @config.available_roles.sort_by {|role_name| profile_text.index(role_name+":")}
  end

  def load_roles
    roles_file_name = @config.profile.roles
    roles_file_path = File.join(@config.config.paths.roles, roles_file_name) + ".yml"
    Loader.config_file_must_exist!('roles file', roles_file_path)

    @config.roles = mash(YAML.load_file(roles_file_path))
    @config.roles.name = roles_file_name
  end

  def load_security_rules
    security_rules_file_name = @config.profile.security_rules

    if security_rules_file_name.blank?
    else
      security_rules_file_path = File.join(@config.config.paths.security_rules, security_rules_file_name) + ".yml"
      Loader.config_file_must_exist!('security rules file', security_rules_file_path)

      @config.security_rules = mash(YAML.load_file(security_rules_file_path))
    end
  end

  def exit_on_missing_roles
    profile_config_role_names = @config.profile.keys - RESERVED_ROLE_NAMES
    roles_config_role_names = @config.roles.keys - RESERVED_ROLE_NAMES

    unknown_roles_in_profile_config = profile_config_role_names - roles_config_role_names

    unless unknown_roles_in_profile_config.empty?
      error "Undefined roles [%s] in profile '%s'" % [unknown_roles_in_profile_config.join(', '), @config.profile.name]
      exit(1)
    end
  end

  def create_combined
    @config.combined = mash
    # combine roles
    @config.available_roles.each {|role_name|
      @config.combined[role_name] = @config.roles[role_name].deep_merge(@config.profile[role_name])

      # now combine configurations - these are arrays that need to be unioned
      @config.combined[role_name].configurations = []
      # first collect all configurations with the same name for this role
      grouped_configurations = ((@config.roles[role_name].configurations || []) +
                                (@config.profile[role_name].configurations || [])).
                                      group_by {|c| c.name }
      # now merge all for the same name
      grouped_configurations.each {|name, configurations|
        merged_configuration = configurations.inject(configurations.first) { |merged, configuration| merged.deep_merge(configuration)}
        @config.combined[role_name].configurations << merged_configuration
      }
    }

    # combine settings
    @config.combined.settings = @config.roles.settings.deep_merge(@config.profile.settings)
  end
end