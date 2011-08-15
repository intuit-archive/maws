class Instance
  attr_accessor :name, :role, :status

  def initialize(n,r,s)
    @name, @role, @status = n,r,s
  end

  def to_s
    col_width = 20
    name_padding = " " * (20-@name.length)
    # role_padding = " " * (20-@role.name.length)
    # status_padding = " " * (20-name.length)

    @name.to_s + name_padding + display_status
  end

  def display_status
    case @status
    when 'unknown' : '?'
    else @status
    end
  end

  def self.for_role(role_name)
    all.select {|i| i.role.name == role_name}
  end

  def self.all
    @all ||= []
  end
end

# build all
# build non-existing
# check version by hash ?
# object for each instance?
# objects start, stop, sync themselves?
# tool knows no state
# establish state
