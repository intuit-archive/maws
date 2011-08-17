require 'lib/command'

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
    puts "SYNC NAME                STATUS"
    puts @selected_instances
  end

end