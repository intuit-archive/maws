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
  end

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

        if options.dump
          info "\n\n------- BEGIN #{config_output_path} -------"
          info generated_config
          info "-------- END #{config_output_path} --------\n\n"
        end

        upload_and_restart(config_output_path, instance, configuration)
      end
    end
  end

  def upload_and_restart(config_output_path, instance, configuration)
    keypair_file = KEYPAIR_DIR + instance.keypair + ".pem"
    host = instance.dns_name
    user = "root"

    info "connecting to '#{user}@#{host}'..."

    Net::SSH.start(host, user,
              :keys => [keypair_file],
              :verbose => :warn,
              :auth_methods => 'publickey') do |ssh|

      ssh.scp.upload!(config_output_path, configuration.remote.location)

      timestamp = ssh.exec!("stat -c %y #{configuration.remote.location}")
      info "            new timestamp (for #{configuration.remote.location}): " + timestamp

      info "   executing stop command: " + configuration.remote.stop
      result = ssh.exec!(configuration.remote.stop)
      info result if result

      info "   executing start command: " + configuration.remote.start
      result = ssh.exec!(configuration.remote.start)
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

    elsif param_config.select_many
      context = "#{instance.role_name}-#{template_name}-#{param_name}"
      @profile.register_instance_source(context, :defined, param_config.select_many.role, param_config.select_many.chunk_size, param_config.select_many.scope)
      @profile.next_instances_chunk(context)

    else
      param_config
    end
  end
end