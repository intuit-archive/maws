require 'lib/command'

class Test < Command
  def run!
    puts "test command says 'test'"
  end
end