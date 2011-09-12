require 'lib/instance'

class Command
  attr_accessor :options, :connection, :default_region, :default_zone

  def initialize(profile, roles_config)
    @profile = profile
    @roles_config = roles_config
  end

  def run!
    puts "generic command does nothing"
  end

  def add_generic_options(parser)
    available_roles = @roles_config.keys.join(', ')
    parser.opt :roles, "List of roles (available: #{available_roles})", :type => :strings
    parser.opt :names, "Names of machines", :type => :strings
    parser.opt :all, "All roles", :short => '-A', :type => :flag
    parser.opt :region, "Region", :short => '-R', :type => :string, :default => @default_region
    parser.opt :zone, "Zone", :short => '-Z', :type => :string, :default => @default_zone
  end

  def add_specific_options(parser)
  end

  def verify_options
    unless options.region && !options.region.empty?
      Trollop::die "Region must be specified in command line options OR as 'default_region' in #{CONFIG_CONFIG_PATH}"
    end

    unless options.zone && !options.zone.empty?
      Trollop::die "Zone must be specified in command line options OR as 'default_zone' in #{CONFIG_CONFIG_PATH}"
    end
  end

  def verify_configs
  end

  def sync_only_specified?
    false
  end

  def specified_instances
    @profile.specified_instances
  end

  def pretty_describe(title, data)
    pretty_describe_heading(title)
    if data.is_a? String
      info data
    else
      ap data
    end
    pretty_describe_footer
  end

  def pretty_describe_heading(title)
    title = title[0,62]
    info "++++++++++ " + title + " " + ("+" * (75 - title.length))
  end

  def pretty_describe_footer
    info "+-------------------------------------------------------------------------------------+\n\n\n"
  end

  def sync_profile_instances
    sync_instances = sync_only_specified? ? @profile.specified_instances : @profile.defined_instances
    sync_instances.each do |i|
      i.connection = @connection
      i.sync!
    end
  end

end