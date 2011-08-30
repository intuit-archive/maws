require 'lib/command'
require 'terminal-table/import'

class Describe < Command
  def run!
    specified_instances.each do |i|
      title = i.name.to_s.upcase
      pretty_describe(title, i.aws_description)
    end
  end

  def sync_only_specified?
    true
  end
end