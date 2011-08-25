require 'lib/instance'

class Command
  attr_accessor :options
  attr_reader :connection

  def initialize(profile, roles_config)
    @profile = profile
    @roles_config = roles_config
  end

  def connection=(connection)
    @connection = connection
    sync_profile_instances
    @profile.select_instances_by_command_options
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

  def specified_instances
    @profile.specified_instances
  end

  protected
  def sync_profile_instances
    @profile.defined_instances.each do |i|
      i.connection = @connection
      i.sync
    end
  end

end