require 'lib/command'
require 'terminal-table/import'

class Status < Command
  def add_specific_options(parser)
    # parser.opt :force, "Force listing all existing instances", :type => :flag, :default => false
    # TODO: implement this
  end

  def run!
    return if specified_instances.empty?
    t = table %w(NAME STATUS SERVER KEYPAIR)
    specified_instances.each {|i| t << instance_to_table_row(i)}
    puts t
  end

  def instance_to_table_row(instance)
    name = instance.name
    status =  display_status(instance.status)
    dns_name = if instance.dns_name
      "root@" + instance.dns_name
    else
      ""
    end

    [name.to_s, status, dns_name, instance.keypair.to_s]
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