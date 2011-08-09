require 'lib/command'

class Test < Command
  def run!
    puts "test command says 'test'"
    p @options
    p @connection
    p @connection.ec2
    p @connection.rds
  end
end