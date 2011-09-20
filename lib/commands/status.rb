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

      headers = instances.first.display_fields_headers
      info "\n\n**** " + role_name.upcase + " *****************"
      info table(headers, *instances.map { |instance| instance.display_fields_values })
    end

  end

  def default_sync_instances
    @profile.specified_instances
  end
end