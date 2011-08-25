require 'lib/command'
require 'erubis'
require 'net/ssh'
require 'net/scp'

class Configure < Command
  TEMPLATE_DIR = "config/templates/"
  TEMPLATE_OUTPUT_DIR = "tmp/"
  KEYPAIR_DIR = "config/keypairs/"

  def run!
    specified_instances.each do |instance|
      next unless instance.status == 'running'
      instance.profile_role_config.configurations.each do |configuration|

        info "configuring #{configuration.template} for #{instance.name}"
        # prepare params for config file interpolation
        resolved_params = {}
        configuration.template_params.each do |param_name, param_config|
          resolved_params[param_name] = resolve_template_param(instance, configuration.template, param_name, param_config)
        end

        # generate config file
        template_path = TEMPLATE_DIR + configuration.template + ".erb"
        template = File.read(template_path)
        generated_config =  Erubis::Eruby.new(template).result(resolved_params)

        config_output_path = TEMPLATE_OUTPUT_DIR + "#{instance.name}--#{instance.aws_id}." + configuration.template
        info "generated  '#{config_output_path}'"
        File.open(config_output_path, "w") {|f| f.write(generated_config)}

        upload_and_restart(config_output_path, instance, instance_config, remote_config)
      end
    end
  end

  def upload_and_restart(config_output_path, instance, instance_config, remote_config)
    keypair_file = KEYPAIR_DIR + instance_config.keypair + ".pem"
    host = instance.dns_name
    user = "root"

    info "connecting to '#{user}@#{host}'..."

    Net::SSH.start(host, user,
              :keys => [keypair_file],
              :verbose => :warn,
              :auth_methods => 'publickey') do |ssh|

      ssh.scp.upload!(config_output_path, remote_config.location)

      timestamp = ssh.exec!("stat -c %y #{remote_config.location}")
      info "            new timestamp (for #{remote_config.location}): " + timestamp

      info "   executing stop command: " + remote_config.stop
      result = ssh.exec!(remote_config.stop)
      info result if result

      info "   executing start command: " + remote_config.start
      result = ssh.exec!(remote_config.start)
      info "      " + result if result
    end

    puts "...done (disconnected from '#{user}@#{host}')\n\n"
  end

  def resolve_template_param(instance, template_name, param_name, param_config)
    if param_config == 'self'
      return instance

    elsif param_config.select_one.is_a? String
      @profile.select_first_instance(:defined, param_config.select_one)

    elsif param_config.select_many.is_a? String
      @profile.select_all_instances(:defined, param_config.select_many)

    elsif param_config.select_one
      context = "#{instance.role_name}-#{template_name}-#{param_name}"
      @profile.register_instance_source(context, :defined, param_config.select_one.role, 1, param_config.select_one.scope)

      @profile.next_instances_chunk(context).first
      # @profile.next_instances_chunk(:define, param_config.select_one.role, )
      # prepare_select_one_template_value(instance, name, value.select_one)

    elsif param_config.select_many
      context = "#{instance.role_name}-#{template_name}-#{param_name}"
      # chunk_size = param_config.select_many.chunk_size.to_i > 0 ?  param_config.select_many.chunk_size.to_i : nil
      @profile.register_instance_source(context, :defined, param_config.select_many.role, param_config.select_many.chunk_size, param_config.select_many.scope)
      @profile.next_instances_chunk(context)

      # prepare_select_many_template_value(instance, name, value.select_many)

    else
      param_config
    end
  end

  # def prepare_select_many_template_value(instance, config_name, select_many_config)
  #   if select_many_config.chunk_size.to_i > 0
  #     @profile.next_instances_chunk(:defined, select_many_config.role, select_many_config.chunk_size.to_i, 1, instance.role)
  #
  #
  #     # @chunk_indexes ||=  {}
  #     # @chunk_indexes[[instance.role, config_name]] ||= 0
  #     #
  #     # chunk_index = @chunk_indexes[[instance.role, config_name]]
  #     # @chunk_indexes[[instance.role, config_name]] += 1
  #     #
  #     # chunk_size = select_many_config.chunk_size.to_i
  #     # available_instances = @profile.instances_for_role(select_many_config.role)
  #     #
  #     # start_index = (chunk_index * chunk_size) % available_instances.count
  #     #
  #     # # make a very long repeating list for simple slicing with guarantee of no overflow
  #     # # even if chunk size is much bigger than available instances
  #     # (available_instances * chunk_size)[start_index,chunk_size].uniq
  #   else
  #     @profile.next_instances_chunk(:defined, select_many_config.role, nil, 1, nil)
  #     # @profile.instances_for_role(select_many_config.role)
  #   end
  # end
  #
  #
  # def prepare_select_one_template_value(instance, config_name, select_one_configs)
  #   @available_instances ||= {}
  #   @available_instances_index ||= {}
  #
  #   @available_instances[[instance.role, config_name]] ||= @profile.instances_for_role(select_one_configs.role)
  #   @available_instances_index[[instance.role, config_name]] ||= 0
  #
  #   pick_from = @available_instances[[instance.role, config_name]]
  #   pick_index = @available_instances_index[[instance.role, config_name]]
  #   @available_instances_index[[instance.role, config_name]] = pick_index + 1
  #
  #   if select_one_configs.group
  #     total_instances_for_role = @selected_instances.select {|i| i.role.name == instance.role.name}.count
  #     group_size = total_instances_for_role/pick_from.count
  #     index = (pick_index / group_size) % pick_from.count
  #   else
  #     index = pick_index % pick_from.count
  #   end
  #
  #   pick_from[index]
  # end
end