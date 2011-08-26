require 'lib/command'
require 'terminal-table/import'

class Describe < Command
  def run!
    specified_instances.each do |i|
      title = i.name.to_s.upcase

      info "++++++++++ " + title + " " + ("+" * (55 - title.length))
      ap i.aws_description
      info "+-----------------------------------------------------------------+\n\n\n"
    end
  end
end