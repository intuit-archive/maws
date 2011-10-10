require 'lib/instance'

class Hashie::Mash
  undef :count # usually count is the number of keys mash has
end

def mash x
  Hashie::Mash.new x
end

class Profile
  RESERVED_ROLE_NAMES = %w(roles lanes name zones aliases)
  attr_reader :all_instances, :defined_instances, :specified_instances, :defined_instances_in_specified_zone

  attr_reader :profile_config, :roles_config
  attr_accessor :command_options, :zones

  def initialize(profile_config, roles_config)
    @profile_config = profile_config
    @roles_config = roles_config
    @zones = []
  end

  def build_defined_instances
    @defined_instances = []
    @defined_instances_in_specified_zone = []
    @specified_instances = []

    defined_role_names.each do |role_name|
      role_config = @roles_config[role_name]
      profile_role_config = @profile_config[role_name]

      profile_role_config.count.times do |i|
        instances = []
        name = "%s-%s-%d" % [self.name,role_name,i+1]
        if (role_config.scope || profile_role_config.scope) == 'region'
          instance = Instance.new_for_service(role_config.service, name, 'unknown', self, role_config, profile_role_config, @command_options)
          instances << instance
          @defined_instances_in_specified_zone << instance
        else
          profile_config.zones.each {|z|
            instance = Instance.new_for_service(role_config.service, name + z, 'unknown', self, role_config, profile_role_config, @command_options)
            instances << instance
            @defined_instances_in_specified_zone << instance if z == @command_options.zone
          }
        end

        @defined_instances += instances
      end
    end
  end

  # what is :first, :all, :chunk
  # options are:
  #   :chunk_size - how big the chunks are
  #   :chunk_key  - unique name of the context for looping over all instances in chunks. every time calling this method with same key will return next chunk
  #   :from       - nil to pick default scope for role_name, otherwise :zone or :region
  def select(what, role_name, options = {})
    role_config = @roles_config[role_name]
    profile_role_config = @profile_config[role_name]

    # :zone or :region
    from = (options[:from] || (role_config.scope || profile_role_config.scope)).to_sym
    source_instances = (from == :zone) ? @defined_instances_in_specified_zone : @defined_instances
    source_instances = source_instances.find_all {|i| i.role_name == role_name }

    what = :all if what == :chunk && options[:chunk_size].nil?

    case what
    when :all : source_instances
    when :first : source_instances.first
    when :chunk : pick_next_chunk(source_instances, options[:chunk_size], options[:chunk_key])
    end
  end

  def pick_next_chunk(all, size = 1, key = "")
    # this is the starting index of the current chunk
    # this index doesn't wrap around, it needs to be wrapped by the lookup methiod
    @chunk_indexes ||= {}
    @chunk_indexes[key] ||= 0

    index = @chunk_indexes[key] % all.count # real index
    @chunk_indexes[key] += size # update for next time this is called

    # so we don't have to do any math to wrap it
    big_all = all * size
    big_all[index,size]
  end

  def specified_instances_for_role(name)
    @role_grouped_specified_instances ||= @specified_instances.group_by {|i| i.role_name}
    @role_grouped_specified_instances[name]
  end

  def name
    @profile_config.name
  end

  def missing_role_names
    available_role_names = (@roles_config.keys - RESERVED_ROLE_NAMES)
    defined_role_names - available_role_names
  end

  def defined_role_names
    @profile_config.keys - RESERVED_ROLE_NAMES
  end

  def specified_role_names
    @specified_role_names ||= @specified_instances.map {|i| i.role_name}.uniq.sort
  end

  def select_instances_by_command_options
    @specified_instances = if @command_options.all
      @defined_instances_in_specified_zone
    else
      @defined_instances_in_specified_zone.find_all do |i|
        if @command_options.roles
          @command_options.roles.include? i.role_name
        elsif @command_options.names
          @command_options.names.include? i.name
        end
      end
    end
  end
end