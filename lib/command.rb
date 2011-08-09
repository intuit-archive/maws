class Command
  attr_accessor :options, :connection

  def initialize(profile, roles)
    @profile = profile
    @roles = roles
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
end