require 'lib/command'
require 'lib/volumes_command'
require 'terminal-table/import'

class VolumesStatus < VolumesCommand
  def run!
    super

    if @ebs_instances_for_specified_roles.empty?
      info "NO VOLUMES FOR SPECIFIED ROLES (try -A for all roles)"
      return
    end


    attached, unattached =  @ebs_instances_for_specified_roles.partition {|i| i.attached?}

    attached = attached.sort_by {|i| [i.name, i.device.to_s]}
    unattached.sort_by {|i| i.name}

    info "**** " + "ATTACHED EBS VOLUMES" + " *****************"
    list_ebs_instances(attached)

    info "\n\n**** " + "UNATTACHED EBS VOLUMES" + " *****************"
    list_ebs_instances(unattached)
  end

  def list_ebs_instances(instances)
    if instances.nil? || instances.empty?
      info "none available"
      return
    end

    headers = instances.first.display_fields_headers
    table_rows = []
    grouped_instances = instances.
                            group_by{|i| i.name}.
                            to_a.sort_by {|group| group[0]} # sort by name

    grouped_instances.each_with_index do |(name, instances), i|
      instances.each {|instance|
        table_rows << instance.display_fields_values
      }

    end
    # ap headers
    # ap table_rows
    info table(headers, *table_rows)
  end
end