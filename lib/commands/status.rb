require 'lib/command'
require 'terminal-table/import'

class Status < Command
  def add_specific_options(parser)
    # parser.opt :force, "Force listing all existing instances", :type => :flag, :default => false
    # TODO: implement this
  end

  def run!
    if specified_instances.empty?
      puts table(table_header, Array.new(table_header.size, ""))
    else
      puts table(table_header, *specified_instances.map { |instance| instance_to_table_row(instance) })
    end
  end

  def table_header
    ["NAME", "STATUS", "SERVER", "KEYPAIR"]
  end

  def instance_to_table_row(instance)
    name = instance.name
    status =  display_status(instance.status)
    dns_name = if instance.dns_name
      if instance.is_a? Instance::EC2
        "root@" + instance.dns_name
      else
        instance.dns_name
      end
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

  def sync_only_specified?
    true
  end
end