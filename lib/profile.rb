require 'lib/instance'

class Hashie::Mash
  undef :count # usually count is the number of keys mash has
end

def mash x
  Hashie::Mash.new x
end

class Profile
  RESERVED_ROLE_NAMES = %w(roles lanes name)
  attr_reader :all_instances, :defined_instances, :specified_instances

  attr_reader :profile_config, :roles_config
  attr_accessor :command_options

  def initialize(profile_config, roles_config)
    @profile_config = profile_config
    @roles_config = roles_config
  end


  def next_instances_chunk(context)
    @instance_sources ||= {}
    source = @instance_sources[context]
    raise "no such source #{context}" unless source

    index = @instance_source_indexes[context]
    @instance_source_indexes[context] += 1

    # all available instances that could match this source
    instances = select_all_instances(source.instance_set, source.role_name)

    if !source.chunk_size || source.chunk_size == 0
      # no chunk size means return all
      return instances
    elsif source.chunk_size == 1
      # return one from instances
      return [instances[index % instances.count]]
    else
      start_index = (index * source.chunk_size) % instances.count

      # hacky way to make sure there will be no overflows
      return(instances * source.chunk_size)[start_index,source.chunk_size]
    end
  end

  # context is used for keeping track of what set we are looping over
  # instance_set is one of :all, :defined, :specified
  # role name is a string describing the role
  # chunk_size is an integer or nil. nil and 0 mean all
  # scope - if specified limit source of chunks to :zone, :lane or :region
  # if not specified
  def register_instance_source(context, instance_set, role_name, chunk_size, scope = nil)
    @instance_sources ||= {}
    @instance_source_indexes ||= {}
    return if @instance_sources[context]

    chunk_size = chunk_size.to_i > 0 ? chunk_size.to_i : nil
    @instance_sources[context] = mash({
      :instance_set => instance_set,
      :role_name => role_name,
      :chunk_size => chunk_size.to_i,
      :scope => scope})

    @instance_source_indexes[context] = 0
  end

  def grouped_instances(instance_set, role_name)
    if @grouped_instances && @grouped_instances[instance_set] && !@grouped_instances[instance_set][role_name].nil?
      return @grouped_instances[instance_set][role_name]
    end

    @grouped_instances ||= {}
    @grouped_instances[instance_set] ||= {}
    @grouped_instances[instance_set][role_name] = []

    instances = case instance_set
    when :all : @all_instances
    when :defined : @defined_instances
    when :specified : @specified_instances
    end

    @grouped_instances[instance_set][role_name] = instances.select {|i| i.role_name == role_name}
  end



  def select_first_instance(instance_set, role_name, scope = nil)
    grouped_instances(instance_set, role_name).first
  end

  def select_all_instances(instance_set, role_name = nil, scope = nil)
    grouped_instances(instance_set, role_name)
  end

  def build_defined_instances
    @all_instances = []
    @defined_instances = []
    @specified_instances = []

    defined_role_names.each do |role_name|
      role_config = @roles_config[role_name]
      profile_role_config = @profile_config[role_name]
      profile_role_config.count.times do |i|
        name = "%s-%s-%d" % [self.name,role_name,i+1]
        unless profile_role_config.scope == 'region'
          name << @command_options.zone
        end
        instance = Instance.new_for_service(role_config.service, name, 'unknown', self, role_config, profile_role_config, @command_options)
        @defined_instances << instance
      end
    end
  end


  def instance_with_name(name)
    @name_grouped_instances ||= @defined_instances.group_by {|i| i.name}
    @name_grouped_instances[name].first
  end

  def instances_for_role(name)
    @role_grouped_instances ||= @defined_instances.group_by {|i| i.role_name}
    @role_grouped_instances[name]
  end

  def specified_instances_for_role(name)
    @role_grouped_specified_instances ||= @specified_instances.group_by {|i| i.role_name}
    @role_grouped_specified_instances[name]
  end

  def name
    @profile_config.name
  end

  def missing_role_names
    available_role_names = @roles_config.keys
    defined_role_names - available_role_names
  end

  def defined_role_names
    @profile_config.keys - RESERVED_ROLE_NAMES
  end

  def select_instances_by_command_options
    @specified_instances = if @command_options.all
      @defined_instances
    else
      @defined_instances.select do |i|
        if @command_options.roles
          @command_options.roles.include? i.role_name
        elsif @command_options.names
          @command_options.names.include? i.name
        end
      end
    end
  end
end