require 'maws/command'

class Teardown < Command
  def description
    "teardown - destroys all instances that are not specified, but exist on AWS"
  end

  def run!
    instances.aws.not_specified.alive.each {|i| i.destroy}
  end
end