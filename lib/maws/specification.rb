class Specification
  LARGEST_INDEX = 999

  attr_accessor :existing_instances

  def initialize(config, spec)
    @config = config
    @spec = spec
  end

  # [:ec2, :rds, :elb]
  def services
    roles.map { |role_name|
      @config.roles[role_name].service
    }.compact.uniq.map{|service| service.to_sym}
  end

  # ['a', 'b', 'd']
  def zones
    found = @config.available_zones.find_all {|az|
      @spec.match(%r{\b#{az}\b})
    }
    found.empty? ? @config.available_zones : found
  end

  def zones_for_role(role)
    if @config.combined[role].scope != 'zone'
      [nil]
    else
      zones
    end
  end

  # {'app' => [1,2,3,4], 'web' => [3], 'db' => [4,5,6,7,8,9,10,11,12]}
  def role_indexes
    indexes = {}
    roles.each {|role_name|
      indexes[role_name] = indexes_range_for_role(role_name)
    }

    indexes.delete_if {|role, index_range| index_range.nil?}
    indexes.each {|role, index_range| indexes[role] = resolve_index_range(role, index_range)}

    indexes
  end

  # ('app', [nil, *]) => [1,2,3,4,5,6,7]
  def resolve_index_range(role, range)
    lower = range[0]
    upper = range[1]

    lower = 1 if lower.nil?

    # replace upper
    if upper == '*'
      # max existing index
      max_existing = @existing_instances.matching(:role => role).map {|i| i.index}.max.to_i
      max_profile = @config.profile[role].count

      upper = [max_profile, max_existing].max
    end

    if upper.nil?
      # max index in profile
      upper = @config.profile[role].count
    end

    lower.upto(upper).to_a
  end

  def indexes_range_for_role(role)
    # 'app'       =>  [nil, nil, nil]     => [nil, nil]
    # 'app-'      =>  [nil, nil, nil]     => [nil, nil]
    # 'app-*'     =>  ["*", nil, nil]     => [nil, '*']
    # 'app-3'     =>  ["3", nil, nil]     => [3,3]
    # 'app-3-'    =>  ["3", '-', nil]     => [3, nil]
    # 'app-3-*'   =>  ["3", '-', "*"]     => [3, '*']
    # 'app-1-3'   =>  ["1", '-', "3"]     => [1, 3]

    # '*' => [nil, '*']
    # ''  => [nil, nil]


    md = @spec.match(%r{\b#{role}(?=\b)-?(?![^\*\d\s])(\d+|\*)?(-)?(\d+|\*)?})

    # no match, either badly formed specification
    # or '*' or '' (star and blank) specs
    if md.nil?
      anyzone = zones.join('')
      index = if @spec.match(%r{^[#{anyzone}\s]*\*[#{anyzone}\s]*$}) # single '*' with zones
        [nil, '*']
      elsif @spec.match(%r{^[#{anyzone}\s]*$}) # blank
        [nil, nil]
      else
        nil
      end
      return index
    end

    lower, separator, upper = md[1], md[2], md[3]

    return nil unless lower.nil? || lower == '*' || lower =~ /^\d+$/
    return nil unless upper.nil? || upper == '*' || upper =~ /^\d+$/



    # convert to integers
    lower = lower.to_i unless lower == '*' or lower.nil?
    upper = upper.to_i unless upper == '*' or upper.nil?

    # single star is upper bound, not lower bound
    lower, upper = upper, lower if lower == '*'

    # lower digit without separator and without upper digit means single index
    if lower and separator.nil? and upper.nil?
      upper = lower
    end

    [lower, upper]
  end

  def roles
    roles = @config.available_roles.find_all { |role_name| @spec.include?(role_name) }
    roles = @config.available_roles if roles.blank? # use all if none are specified
    roles
  end
end
