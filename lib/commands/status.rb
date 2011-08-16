require 'lib/command'
require 'awesome_print'
class Status < Command
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
    @profile.dump_state
  end

end