require 'lib/command'

class Status < Command
  def add_specific_options(parser)
    # parser.opt :force, "Force listing all existing instances", :type => :flag, :default => false
    # TODO: implement this
  end

  def run!
    puts "NAME                     STATUS                   SERVER\
                                                KEYPAIR"

    # instances = options.force ? @profile.all_instances : @selected_instances
    @selected_instances.each {|i| puts instance_to_s(i)}
  end

  def instance_to_s(instance)
    name = instance.name
    status =  display_status(instance.status)
    dns_name = if instance.dns_name
      "root@" + instance.dns_name
    else
      ""
    end

    col_width = 25
    name_padding = " " * (col_width-name.length)
    status_padding = " " * (col_width-status.length)


    name.to_s + name_padding + status + status_padding + dns_name + "\t" +instance.keypair.to_s
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