require 'maws/command'
require 'terminal-table/import'

class Status < Command
  def description
    "status - show information about specified instances"
  end

  def run!
    instances.specified
    if instances.specified.empty?
      info "no instances specified"
      return
    end

    roles_list = @config.available_roles

    instances.specified.roles_in_order_of(roles_list).each { |role_name|
      role_instances = instances.specified.with_role(role_name)
      next if role_instances.empty?
      InstanceDisplay.display_collection_for_role(role_name, role_instances)
    }

  end
end