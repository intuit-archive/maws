require 'lib/command'
require 'erubis'

class Configure < Command
  TEMPLATE_DIR = "config/templates/"
  def run!
    @selected_instances.each do |instance|
      role = instance.role
      instance_config = @profile.profile_for_role(role.name).config
      instance_config.configs.each do |config_file|
        config_file = config_file.dup
        template_file = config_file.delete(:template)
        copy_to_location = config_file.delete(:copy_to_location)
        restart_command = config_file.delete(:restart_command)
        config_file.delete(:copy_cap_command)

        params = {}
        config_file.each do |param, value|
          params[param] = prepare_template_value(instance, param, value)
        end

        template_path = TEMPLATE_DIR + template_file + ".erb"
        template = File.read(template_path)
        generated_config =  Erubis::Eruby.new(template).result(params)
        puts generated_config
      end
    end
  end

  def prepare_template_value(instance, name, value)
    if value == 'self'
      return instance
    elsif value.select_one.is_a? String
      @profile.instances_for_role(value.select_one).first
    elsif value.select_one
      prepare_select_one_template_value(instance, name, value.select_one)
    elsif value.select_many
      prepare_select_many_template_value(instance, value.select_many)
    else value
    end
  end

  def prepare_select_one_template_value(instance, config_name, select_one_configs)
    @available_instances ||= {}
    @available_instances_index ||= {}

    @available_instances[[instance.role, config_name]] ||= @profile.instances_for_role(select_one_configs.role)
    @available_instances_index[[instance.role, config_name]] ||= 0

    pick_from = @available_instances[[instance.role, config_name]]
    pick_index = @available_instances_index[[instance.role, config_name]]
    @available_instances_index[[instance.role, config_name]] = pick_index + 1

    if select_one_configs.group
      raise "select_one: group parameter not implemented"
    else
      index = pick_index % pick_from.count
    end

    pick_from[index]
  end
end