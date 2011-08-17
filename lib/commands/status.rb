require 'lib/command'

class Status < Command
  def run!
    puts "NAME                STATUS"
    @selected_instances.each {|i| puts instance_to_s(i)}
  end

  def instance_to_s(instance)
    name = instance.name
    status = instance.status

    col_width = 20
    name_padding = " " * (col_width-name.length)

    name.to_s + name_padding + display_status(status)
  end

  def display_status(status)
    case status
    when 'unknown' : '?'
    when 'non-existant' : 'n/a'
    when 'terminated' : 'n/a (terminated)'
    else status
    end
  end

end