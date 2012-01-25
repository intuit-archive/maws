class InstanceDisplay
  def self.display_collection_for_role(role, instances)
    headers = instances.first.display.headers
    service_title = instances.first.service.to_s.downcase
    info "\n\n**** " + role.upcase + " * #{service_title} ****************"

    # separate by zone
    previous_zone = instances.zones.first
    rows = []
    instances.map {|instance|
      if previous_zone == instance.zone
        rows << instance.display.values
      else
         previous_zone = instance.zone
         rows << instance.display.blank_values
         rows << instance.display.values
       end
    }

    info table(headers, *rows)
  end

  def initialize(instance, fields)
    @instance = instance
    @fields = fields
  end

  def headers
    @fields.map {|f| f.to_s.upcase.gsub('_', ' ')}
  end

  def values
    @fields.collect do |field|
      value = value(field, @instance.send(field))
    end
  end

  def blank_values
    @fields.map { "" }
  end

  def value(field, value)
    if field.to_sym == :status
      status(value)
    else
      value.to_s
    end
  end

  def status(status)
    case status
    when 'unknown' : '?'
    when 'non-existant' : 'n/a'
    when 'terminated' : 'n/a (terminated)'
    else status.to_s
    end
  end

  def pretty_details
    title = @instance.name.to_s.upcase
    data = @instance.description.description

    InstanceDisplay.pretty_describe(title, data)
  end

  def self.pretty_describe(title, data)
    pretty_describe_heading(title)
    if data.is_a? String
      info data
    else
      ap data
    end
    pretty_describe_footer
  end

  def self.pretty_describe_heading(title)
    title = title[0,62]
    info "++++++++++ " + title + " " + ("+" * (75 - title.length))
  end

  def self.pretty_describe_footer
    info "+-------------------------------------------------------------------------------------+\n\n\n"
  end
end