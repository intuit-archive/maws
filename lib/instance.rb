require 'lib/mash'
require 'lib/instance_matcher'
require 'lib/instance_display'


class Instance
  attr_accessor :name
  attr_accessor :region, :zone, :role, :index, :groups, :prefix
  attr_reader :description

  NA_STATUS = 'n/a'

  def self.create(maws, config, prefix, zone, role, index, options = {})
    options = mash(options)

    service = options.service || config.combined[role].service
    region = options.region || config.region
    name = options.name || name_for(config, prefix, zone, role, index)

    klass = Instance.const_get("#{service.to_s.upcase}")

    klass.new(maws, config, name, region, prefix, zone, role, index)
  end

  def self.name_for(config, prefix, zone, role, index)
    add_prefix = prefix.empty? ? "" : prefix + "."
    "#{add_prefix}#{config.profile.name}-#{role}-#{index}#{zone}"
  end

  def initialize(maws, config, name, region, prefix, zone, role, index)
    @maws = maws
    @config = config
    @name = name
    @region = region
    @zone = zone
    @role = role
    @index = index

    @prefix = prefix

    @description = mash
    @groups = %w(all)
  end

  def connection
    @maws.connection
  end

  def instances
    @maws.instances
  end

  def description=(description)
    # never nil
    @description = description || mash
  end

  def logical_zone
    @zone
  end

  def physical_zone
    @zone || @description.physical_zone || @config.specified_zones.first
  end

  def aws_id
    description.aws_id
  end

  def status
    description.status || 'n/a'
  end

  def region_zone
    region + zone
  end

  def region_physical_zone
    region + physical_zone
  end


  def terminated?
    status == 'terminated'
  end

  def alive?
    aws_id && !terminated?
  end

  def to_s
    "#{name}   #{status}    #{aws_id}"
  end

  def inspect
    "<#{self.class} #{to_s}>"
  end

  def has_approximate_status?(approximate_status)
    if approximate_status == "n/a" or approximate_status == "terminated"
      !alive?
    elsif approximate_status == "ssh"
      self.respond_to?(:ssh_available?) ? self.ssh_available? : has_approximate_status?("available")
    elsif approximate_status == "running" || approximate_status == "available"
      status == "running" || status == "available"
    else
      approximate_status == status
    end
  end

  def method_missing(method_name, *args, &block)
    config(method_name) ||
    description[method_name] ||
    @config.command_line[method_name]
  end

  def config(key, required=false)
    if required && @config.combined[role][key].nil?
      raise ArgumentError.new("Missing required config: #{key}")
    end

    @config.combined[role][key]
  end

  def security_groups
    groups = config(:security_groups).to_a.dup
    groups << "#{service}_default"

    if @config.profile.security_rules and @config.profile.security_rules[role]
      groups << "#{@profile.name}-#{role_name}"
    end

    groups
  end

  def service
    raise ArgumentError, "No service for generic instance"
  end

  def display_fields
    [:zone, :name, :status]
  end

  def display
    InstanceDisplay.new(self, display_fields)
  end

  def matches?(filters={})
    approximate_status = filters.delete(:approximate_status)
    matched = InstanceMatcher.matches?(self, filters)

    # approximate status is not a single state
    # it might require an ssh connection
    matched &&= has_approximate_status?(approximate_status) if approximate_status
    matched
  end

  protected

end

# load all instance files
Dir.glob(File.dirname(__FILE__) + '/instance/*.rb') {|file| require file}




