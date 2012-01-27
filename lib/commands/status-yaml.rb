require 'lib/command'
require 'terminal-table/import'

class StatusYaml < Command
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
      next if instances.nil? || instances.empty? || instances.collect(&:private_dns_name).all? {|pdn| !pdn.is_a?(String) || pdn.empty?}

      headers = instances.first.display_fields_headers

      info "#{role_name}: "
      instances.each do |i|
      info "  - #{i.private_dns_name}"
      end
    end

  end

  def default_sync_instances
    @profile.specified_instances
  end
end
