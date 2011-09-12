require 'lib/command'
require 'terminal-table/import'

class Status < Command
  def add_specific_options(parser)
    # parser.opt :force, "Force listing all existing instances", :type => :flag, :default => false
    # TODO: implement this
  end

  def run!
    if specified_instances.empty?
      info "NO INSTANCES SPECIFIED"
      return
    end

    @profile.defined_role_names.sort.each do |role_name|
      instances = @profile.specified_instances_for_role(role_name)
      next if instances.nil? || instances.empty?

      fields = instances.first.display_fields
      headers = fields.map {|f| f.to_s.upcase.gsub('_', ' ')}

      info "\n\n**** " + role_name.upcase + " *****************"
      info table(headers, *instances.map { |instance| instance_to_table_row(instance) })
    end
  end


  def instance_to_table_row(instance)
    fields = instance.display_fields

    fields.collect do |field|
      value = instance.send(field)
      if field == :status
        value = display_status(value)
      end
      value.to_s
    end
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