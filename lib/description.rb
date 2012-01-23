class Description
  attr_reader :description

  def self.create(description)
    service = description[:service]
    klass = Description.const_get("#{service.to_s.upcase}")
    klass.new(description)
  end

  def [](key)
    description[key]
  end

  def method_missing(method_name, *args, &block)
    description[method_name.to_sym]
  end

  def initialize(description)
    raise "use #{self.class}::create instead"
  end

  # logical zone (what the zone is according to maws categorization)
  def zone
    # us-east-1a => a
    logical_zone
  end

  # zone where the instance really lives
  # this has meaning for RDS with multi-zone = true and for EC2 with region scope
  def physical_zone
    region_zone[-1,1]
  end

  def region
    # us-east-1a => us-east-1
    region_zone[0...-1]
  end

  def name_re
    /^(.+\.)?(.+)-(.+)-(\d+)(\w)?$/
  end

  def prefix
    # old.foo-test-app-1z => old
    md = name.match(name_re)
    md[1].to_s[0...-1] if md
  end

  def profile
    # foo-test-app-1z => foo-test
    md = name.match(name_re)
    md[2] if md
  end

  def role
    md = name.match(name_re)
    md[3] if md
  end

  def index
    md = name.match(name_re)
    md[4].to_i if md
  end

  def logical_zone
    md = name.match(name_re)
    md[5] if md
  end

  def create_instance(maws, config)
    instance = Instance.create(maws, config, prefix, zone, role, index, {:service => service, :name => name, :region => region })
    instance.description = self
    instance
  end
end

# load all description files
Dir.glob(File.dirname(__FILE__) + '/description/*.rb') {|file| require file}