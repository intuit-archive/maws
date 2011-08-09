require 'lib/command'
require 'awesome_print'
class Test < Command
  def run!
    puts "test command says 'test'"
    # p @options
    # p @connection
    # p @connection.ec2
    # p @connection.rds

    @ec2 = @connection.ec2
    @rds = @connection.rds

    ap @ec2.describe_instances
    ap @rds.describe_db_instances
  end
end