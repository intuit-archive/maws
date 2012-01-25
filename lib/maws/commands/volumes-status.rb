require 'maws/command'
require 'maws/volumes_command'
require 'terminal-table/import'

class VolumesStatus < VolumesCommand
  def description
     "volumes-status - show brief status information for EBS volumes for specified roles"
  end

  def run!
    super
    attached = instances.specified.ebs.matching(:attached? => true)
    unattached = instances.specified.ebs.matching(:attached? => false)

    info "\n**** " + "ATTACHED EBS VOLUMES" + " *****************"
    list_ebs_instances(attached)

    info "\n\n**** " + "UNATTACHED EBS VOLUMES" + " *****************"
    list_ebs_instances(unattached)
  end

  def list_ebs_instances(instances)
    if instances.empty?
      info "none available"
      return
    end

    headers = instances.first.display.headers
    table_rows = []
    grouped_instances = instances.
                            group_by{|i| i.name}.
                            to_a.sort_by {|group| group[0]} # sort by name

    grouped_instances.each_with_index do |(name, instances), i|
      instances.each {|instance|
        table_rows << instance.display.values
      }

    end

    info table(headers, *table_rows)
  end
end