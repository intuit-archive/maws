require 'lib/instance'

class Command
  attr_accessor :maws, :connection

  def description
    "command - does nothing"
  end

  def instances
    maws.instances
  end


  def initialize(config)
    @config = config
    @maws = nil
  end

  def connection
    @maws.connection
  end

  def run!
    puts "generic command does nothing"
  end


  def add_generic_options(parser)
    available_roles = @config.available_roles.join(', ')
    parser.opt :selection, "Selection of instances
         any of the following:
             zones (a, b, c, etc.)
             indexes (2, 1-10, 5-, -10, *) where * is all existing indexes and blank means all defined in profile
             role names (available: #{available_roles})
         in any order and separated by spaces", :type => :string, :default => nil
    parser.opt :prefix, "Prefix", :short => '-p', :type => :string, :default => ""
    parser.opt :region, "Region", :short => '-R', :type => :string, :default => @config.config.default_region
  end

  def add_specific_options(parser)
  end

  def process_options
    @config.region = @config.command_line.region
    @config.prefix = @config.command_line.prefix
  end

  def verify_options
    if @config.command_line.region.blank?
      Trollop::die "Region must be specified in command line options OR as 'default_region' in #{@config.config.paths.config}"
    end

    if @config.command_line.selection.nil?
      Trollop::die "Must specify a selection of some instances"
    end
  end

  def verify_configs
  end

end