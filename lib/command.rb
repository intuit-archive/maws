require 'lib/instance'

class Command
  attr_accessor :options, :connection

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
    parser.opt :region, "Region", :short => '-R', :default => 'us-east-1'
    parser.opt :zone, "Zone", :short => '-Z', :default => 'b'
  end

  def add_specific_options(parser)
  end

  def verify_options
  end

  def sync_only_specified?
    false
  end

  def specified_instances
    @profile.specified_instances
  end

  def pretty_describe(title, data)
    info "++++++++++ " + title + " " + ("+" * (55 - title.length))
    if data.is_a? String
      info data
    else
      ap data
    end
    info "+-----------------------------------------------------------------+\n\n\n"
  end

  def sync_profile_instances
    sync_instances = sync_only_specified? ? @profile.specified_instances : @profile.defined_instances
    sync_instances.each do |i|
      i.connection = @connection
      i.sync!
    end
  end

end