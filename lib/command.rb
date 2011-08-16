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
  end

  def run!
    puts "generic command does nothing"
  end

  def add_generic_options(parser)
    available_roles = @roles.keys.join(', ')
    parser.opt :roles, "List of roles (available: #{available_roles})", :type => :strings
    parser.opt :names, "Names of machines", :type => :strings
    parser.opt :all, "All roles", :short => '-A', :type => :flag
  end

  def add_specific_options(parser)
  end

  protected
  def sync_profile_instances
    Instance.all.each do |i|
      description = @connection.description_for_name(i.name)
      i.aws_description = description if description
    end
  end
end