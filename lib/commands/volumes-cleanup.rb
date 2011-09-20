require 'lib/command'
require 'lib/volumes_command'
require 'terminal-table/import'

class VolumesCleanup < VolumesCommand
  def run!
    super

    _, unattached_ebs_instances =  @ebs_instances_for_specified_roles.partition {|i| i.attached?}

    if unattached_ebs_instances.empty?
      info "NO UNATTACHED VOLUMES FOR SPECIFIED ROLES (try -A for all roles)"
      return
    end

    unattached_ebs_instances.each {|instance| instance.destroy}
  end
end
