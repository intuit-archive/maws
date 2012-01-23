class InstanceMatcher
  def self.matches?(instance, filters)
    filters.each {|filter, expected_value|
      value = instance.send(filter)
      if value.is_a? Array
        return false if value.find_all {|v| value_matches?(v, expected_value)}.empty?
      else
        return false unless value_matches?(value, expected_value)
      end
    }
    true
  end

  private
  def self.value_matches?(value, expected_value)
    if expected_value.is_a? Array
      return false unless expected_value.include?(value)
    else
      if !expected_value # treat false/nil as the same
        return !value
      else
        return false if expected_value != value
      end
    end
    true
  end
end