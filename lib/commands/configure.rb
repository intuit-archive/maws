require 'lib/command'
require 'erubis'
require 'net/ssh'
require 'net/scp'
require 'open3'

class Configure < Command
  TEMPLATE_DIR = "config/templates/"
  TEMPLATE_OUTPUT_DIR = "tmp/"
  KEYPAIR_DIR = "config/keypairs/"
  def run!
    @selected_instances.each do |instance|
      role = instance.role
      instance_config = @profile.profile_for_role(role.name).config
      instance_config.configs.each do |config_file|
        config_file = config_file.dup
        template_file = config_file.delete(:template)
        remote_config = config_file.delete(:remote)
        config_file.delete(:copy_cap_command)

        # prepare params for config file interpolation
        params = {}
        config_file.each do |param, value|
          params[param] = prepare_template_value(instance, param, value)
        end

        # generate config file
        template_path = TEMPLATE_DIR + template_file + ".erb"
        template = File.read(template_path)
        generated_config =  Erubis::Eruby.new(template).result(params)

        config_output_path = TEMPLATE_OUTPUT_DIR + "#{instance.name}--#{instance.aws_id}." + template_file
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
      info "            new timestamp: " + timestamp

      info "   executing stop command: " + remote_config.stop
      ssh.exec!(remote_config.stop)

      info "   executing start command: " + remote_config.start
      ssh.exec!(remote_config.start)
    end

    puts "...done (disconnected from '#{user}@#{host}')\n\n"
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