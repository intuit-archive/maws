class InstanceCollection
  include Enumerable

  attr_accessor :members

  def initialize(members = [])
    @members = members.sort_by {|m| [m.region, m.zone.to_s, m.role.to_s, m.index || 1]}
  end

  def add(instance)
    @members << instance
  end

  def each
    @members.each {|m| yield m}
  end

  def empty?
    @members.empty?
  end

  def first
    @members.first
  end

  def *(x)
    @members * x
  end

  def matching(filters = {})
    InstanceCollection.new(self.find_all {|i| i.matches?(filters)})
  end

  def not_matching(filters)
    InstanceCollection.new(self.find_all {|i| !i.matches?(filters)})
  end

  def services
    self.map {|i| i.service}.uniq
  end

  def roles
    map{|i| i.role}.uniq
  end

  def zones
    map{|i| i.zone}.uniq
  end

  def roles_in_order_of(roles_list)
    roles.sort_by {|r| roles_list.index(r)}
  end

  # scopes
  def specified
    self.matching(:groups => 'specified')
  end

  def not_specified
    self.not_matching(:groups => 'specified')
  end

  def aws
    self.matching(:groups => 'aws')
  end

  def alive
    self.matching(:alive? => true)
  end

  def not_alive
    self.matching(:alive? => false)
  end

  def with_service(service)
    self.matching(:service => service.to_sym)
  end

  def with_role(role)
    self.matching(:role => role)
  end

  def with_zone(zone)
    self.matching(:zone => zone)
  end

  def without_role(role)
    self.not_matching(:role => role)
  end

  def ebs
    with_service(:ebs)
  end

  def with_approximate_status(status)
    self.matching(:approximate_status => status)
  end
end