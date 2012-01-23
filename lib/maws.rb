require 'lib/instance_collection'
require 'lib/specification'
require 'lib/connection'


class Maws
  attr_reader :instances, :config, :command, :connection, :descriptions

  def initialize(config, command)
    @config = config
    @command = command

    @connection = Connection.new(@config)

    @instances = InstanceCollection.new
    @specification = Specification.new(@config, @config.command_line.selection || "")
  end

  def services
    @specification.services
  end

  def specified_roles
    @specification.roles
  end

  def specified_zones
    @specification.zones
  end

  def run!
    connect
    info "\n"
    info "REGION: #{@config.region}"
    info "AVAILABLE ZONES: #{@connection.available_zones.join(', ')}"
    build_instances

    info "\n"
    info "QUERYING SERVICES: #{instances.services.join(', ')}"
    info "TOTAL #{@config.profile.name.upcase} ON AWS: #{instances.aws.count}  "
    info "TOTAL SELECTED: #{instances.specified.count}"
    info "TOTAL SELECTED ON AWS: #{instances.specified.aws.count}"

    @command.run!
  end

  def connect(services = nil)
    services ||= @specification.services
    @connection.connect(services)

    @config.available_zones = @connection.available_zones
    @config.specified_zones = @specification.zones
  end

  def resync_instances
    @descriptions = @connection.descriptions(services)
    @descriptions.each {|description|
      instance = @instances.matching(:aws_id => description.aws_id).first
      instance.description = description if instance
    }
  end

  def build_instances
    @descriptions = @connection.descriptions(services)

    create_from_descriptions
    create_from_specification
  end

  def create_from_descriptions
    @descriptions.map { |description|
      instance = description.create_instance(self, @config)
      @instances.add(instance)
      instance.groups << "aws"
    }
  end

  def create_from_specification
    @specification.existing_instances = @instances.matching(:groups => 'aws')

    prefix = @config.prefix
    @specification.role_indexes.each {|role_name, indexes|
      @specification.zones_for_role(role_name).each {|zone|
        indexes.each do |index|
          instance = find_or_create_specified(prefix, zone, role_name, index)
          instance.groups << "specified"
        end
      }
    }
  end

  def find_or_create_specified(prefix, zone, role_name, index)
    found = @instances.matching({:zone => zone, :role => role_name, :index => index, :prefix => prefix})
    if !found.empty?
      found.first
    else
      instance = Instance.create(self, @config, prefix, zone, role_name, index)
      @instances.add(instance)
      instance
    end
  end
end
