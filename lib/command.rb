require 'lib/instance'

class Command
  attr_accessor :options
  attr_reader :connection

  def initialize(profile, roles)
    @profile = profile
    @roles = roles
  end

  def connection=(connection)
    @connection = connection
    sync_profile_instances
    select_instances_by_command_options
  end

  def run!
    puts "generic command does nothing"
  end

  def add_generic_options(parser)
    available_roles = @roles.keys.join(', ')
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

  protected
  def sync_profile_instances
    @profile.all_instances.each do |i|
      i.connection = @connection
      i.sync
    end
  end

  def select_instances_by_command_options
    @selected_instances = if options.all
      @profile.all_instances
    else
      @profile.all_instances.select do |i|
        if options.roles
          options.roles.include? i.role.name
        elsif options.names
          options.names.include? i.name
        end
      end
    end
  end
end