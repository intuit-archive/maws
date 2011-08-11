require 'lib/command'
require 'awesome_print'
class Test < Command
  def run!
    # p @options
    # p @connection
    # p @connection.ec2
    # p @connection.rds

    # @ec2 = @connection.ec2
    # @rds = @connection.rds

    # ap @ec2.describe_instances
    # ap @rds.describe_db_instances

    # puts @ec2.describe_regions
    debug_instances_list
  end

  def debug_instances_list
    reserved_names = %w(roles lanes)
    defined_roles = @roles.keys - reserved_names
    puts defined_roles

    all_roles = @roles.collect{|r| r.name}
    undefined_roles = defined_roles - all_roles


    unknown_roles =
    roles_list.each do |role|
      if role.count
        fixed_counts[role] = role.count
      end
    end
  end

  def symbolize(*names)
    names.map {|n| n.to_sym}
  end
end