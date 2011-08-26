require 'lib/command'
require 'erubis'
require 'net/ssh'
require 'net/scp'

class Configure < Command
  TEMPLATE_DIR = "config/templates/"
  TEMPLATE_OUTPUT_DIR = "tmp/"
  KEYPAIR_DIR = "config/keypairs/"


  def add_specific_options(parser)
    parser.opt :dump, "Dump config files before uploading them", :type => :flag, :default => false
    parser.opt :command, "Command to run remotely (either name or a string)", :type => :string, :default => ""
  end

  def run!
    specified_instances.each do |instance|
      next unless instance.status == 'running'
      next unless instance.profile_role_config.configurations || !options.command.empty?
      ssh = ssh_connect_to(instance)


      if options.command.empty?
        # execute all configurations
        instance.profile_role_config.configurations.each do |configuration|
          execute_configuration(ssh, instance, configuration)
        end
      elsif instance.profile_role_config.configurations && instance.profile_role_config.configurations.collect{|c| c.name}.include?(options.command)
        # command specified as name of a config
        configuration = instance.profile_role_config.configurations.find{|c| c.name == options.command}
        execute_configuration(ssh, instance, configuration)
      elsif options.command
         execute_remote_command(ssh, instance, nil, options.command)
      end

      ssh_disconnect(ssh, instance)
    end
  end

  def ssh_connect_to(instance)
    keypair_file = KEYPAIR_DIR + instance.keypair + ".pem"
    host = instance.dns_name
    user = "root"

    info "connecting to '#{user}@#{host}'..."

    Net::SSH.start(host, user,
              :keys => [keypair_file],
              :verbose => :warn,
              :auth_methods => 'publickey')
  end

  def ssh_disconnect(ssh, instance)
    host = instance.dns_name
    user = "root"

    puts "...done (disconnected from '#{user}@#{host}')\n\n"
    ssh.close
  end

  def execute_configuration(ssh, instance, configuration)
    if configuration.template
      upload_template(ssh, instance, configuration)
    elsif configuration.command
      execute_remote_command(ssh, instance, configuration.name, configuration.command)
    end
  end

  def execute_remote_command(ssh, instance, name, command)
    if name
      info "   executing #{name} command: " + command
    else
      info "   executing #{command}"
    end

    result = ssh.exec!(command)
    info result if result
  end

  def upload_template(ssh, instance, configuration)
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

    if options.dump
      info "\n\n------- BEGIN #{config_output_path} -------"
      info generated_config
      info "-------- END #{config_output_path} --------\n\n"
    end

    ssh.scp.upload!(config_output_path, configuration.location)
    timestamp = ssh.exec!("stat -c %y #{configuration.location}")
    info "            new timestamp for #{configuration.location}: " + timestamp
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

    elsif param_config.select_many
      context = "#{instance.role_name}-#{template_name}-#{param_name}"
      @profile.register_instance_source(context, :defined, param_config.select_many.role, param_config.select_many.chunk_size, param_config.select_many.scope)
      @profile.next_instances_chunk(context)

    else
      param_config
    end
  end
end