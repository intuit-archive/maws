require 'lib/command'
require 'lib/volumes_command'
require 'terminal-table/import'

class VolumesCleanup < VolumesCommand
  def description
    "volumes-cleaned - delete unattached EBS volumes for specified roles"
  end

  def run!
    super

    unattached = instances.specified.ebs.matching(:attached? => false)

    if unattached.empty?
      info "no unattached volumes to clean up"
      return
    end

    unattached.each {|i| i.destroy}
  end
end
