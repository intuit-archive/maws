require 'lib/command'

class SetPrefix < Command
  def description
    "set-prefix - sets prefix for specified EC2 instances"
  end

  def add_specific_options(parser)
    parser.opt :prefix_to_set, "Prefix to set", :short => "-P", :type => :string, :default => ""
  end

  def verify_options
    super
    prefix = @config.command_line.prefix_to_set

    Trollop::die "Can't set the prefix to be the same as the prefix currently in scope: '#{@config.prefix}'" if prefix == @config.prefix
  end

  def run!
    prefix = @config.command_line.prefix_to_set

    instances.specified.alive.each {|i| i.set_prefix(prefix) if i.respond_to?(:set_prefix)}
  end
end