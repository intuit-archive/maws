require 'lib/command'
require 'erubis'
require 'net/ssh'
require 'net/scp'

class Configure < Command
  TEMPLATE_OUTPUT_DIR = File.expand_path("tmp", BASE_PATH)

  def add_specific_options(parser)
    parser.opt :dump, "Dump config files before uploading them", :type => :flag, :default => false
    parser.opt :command, "Command to run remotely (either name or a string)", :type => :string, :default => ""
    parser.opt :login_name, "The SSH login name", :short => '-l', :type => :string, :default => "root"
    parser.opt :hostname, "The SSH hostname", :short => '-h', :type => :string, :default => nil
    parser.opt :identity_file, "The SSH identity file", :short => '-i', :type => :string
  end

  def run!
    @ssh_actions = {}

    configurable_instances = specified_instances.select do |instance|
      instance.status == 'running' &&
      (instance.configurations || !options.command.empty?)
    end

    prepare_ssh_actions(configurable_instances)
    execute_ssh_actions(configurable_instances)
  end

  def prepare_ssh_actions(instances)
    instances.each do |instance|
      @ssh_actions[instance] = []
      build_ssh_actions_for_instance(instance)
    end
  end

  def execute_ssh_actions(instances)
    # create threads that execute ssh commands
    threads = []
    ssh_connections = {}
    instances.each do |instance|
      ssh_actions = @ssh_actions[instance]
      next if ssh_actions.empty?

      threads << Thread.new do
        Thread.current[:title] = "#{instance.name} (#{instance.dns_name})"
        Thread.current[:ensured_output] = []

        ssh = ssh_connect_to(instance)
        ssh_connections[instance] = ssh

        ssh_actions.each {|action| action.call(ssh)}

        ssh_disconnect(ssh, instance)
        ssh_connections[instance] = nil
      end
    end

    begin
      threads.each do |t|
        Kernel.sleep 0.03
        t.join
      end
    ensure
      ssh_connections.each do |instance, ssh|
        ssh_disconnect(ssh, instance) if ssh
      end
      print_ensured_output(threads)
    end
  end

  def build_ssh_actions_for_instance(instance)
    if instance.configurations && instance.configurations.collect{|c| c.name}.include?(options.command)
      # command specified as name of a config
      configuration = instance.configurations.find{|c| c.name == options.command}
      execute_configuration(instance, configuration)
    elsif options.command && !options.command.empty?
      queue_remote_command(instance, nil, options.command)
    end
  end

  def ssh_connect_to(instance)
    host = options.hostname || instance.dns_name
    user = options.login_name

    identity_file = options.identity_file || File.join(KEYPAIRS_PATH, "#{instance.keypair}.pem")
    raise ArgumentError.new("Missing identity file: #{identity_file}") if !File.exists?(identity_file)

    info "connecting to '#{user}@#{host}'..."

    Net::SSH.start(host, user, { :keys => [identity_file], :verbose => :warn, :auth_methods => ["publickey"] })
  end

  def ssh_disconnect(ssh, instance)
    host = options.hostname || instance.dns_name
    user = options.login_name

    info "...done (disconnected from '#{user}@#{host}')"
    ssh.close
  end

  def execute_configuration(instance, configuration)
    if configuration.template
      generate_and_queue_upload_template(instance, configuration)
    elsif configuration.command
      queue_remote_command(instance, configuration.name, configuration.command)
    elsif configuration.command_set
      configuration.command_set.to_a.each do |command_name|
        specified_configuration = instance.configurations.find{|c| c.name == command_name}
        execute_configuration(instance, specified_configuration) if specified_configuration
      end
    end
  end

  def queue_remote_command(instance, name, command)
    queue_ssh_action(instance) do |ssh|
      if name
        ensure_output :info, "   executing #{name} command: " + command
      else
        ensure_output :info, "   executing #{command}"
      end

      result = ssh.exec!(command)
      ensure_output :info, result if result
    end
  end

  def generate_and_queue_upload_template(instance, configuration)
    # prepare params for config file interpolation
    resolved_params = {}
    configuration.template_params.each do |param_name, param_config|
      resolved_params[param_name] = resolve_template_param(instance, configuration.template, param_name, param_config)
    end

    # generate config file
    template_path = File.join(TEMPLATES_PATH, configuration.template + ".erb")
    template = File.read(template_path)
    generated_config =  Erubis::Eruby.new(template).result(resolved_params)

    Dir.mkdir(TEMPLATE_OUTPUT_DIR) if !File.directory?(TEMPLATE_OUTPUT_DIR)
    config_output_path = File.join(TEMPLATE_OUTPUT_DIR, "#{instance.name}--#{instance.aws_id}." + configuration.template)
    File.open(config_output_path, "w") {|f| f.write(generated_config)}
    info "generated  '#{config_output_path}'"

    queue_ssh_action(instance) do |ssh|
      ensure_output :info, "configuring #{configuration.template} for #{instance.name}"

      if options.dump
        ensure_output :info, "\n\n------- BEGIN #{config_output_path} -------"
        ensure_output :info, generated_config
        ensure_output :info, "-------- END #{config_output_path} --------\n\n"
      end

      ssh.scp.upload!(config_output_path, configuration.location)

      timestamp = ssh.exec!("stat -c %y #{configuration.location}")
      ensure_output :info, "            new timestamp for #{configuration.location}: " + timestamp
    end
  end

  def resolve_template_param(instance, template_name, param_name, param_config)
    if param_config == 'self'
      return instance

    elsif param_config == 'profile'
      return @profile

    elsif param_config.is_a? String
      return param_config

    elsif param_config.select_one.is_a? String
      context = "#{instance.role_name}-#{template_name}-#{param_name}"
      @profile.select(:chunk, param_config.select_one, :chunk_size => 1, :chunk_key => context).first

    elsif param_config.select_many.is_a? String
      @profile.select(:all, param_config.select_many)

    elsif param_config.select_one
      context = "#{instance.role_name}-#{template_name}-#{param_name}"
      from = param_config.select_one.from # nil means default
      @profile.select(:chunk, param_config.select_one.role, :chunk_size => 1, :chunk_key => context, :from => from)

    elsif param_config.select_many
      context = "#{instance.role_name}-#{template_name}-#{param_name}"
      from = param_config.select_many.from # nil means default
      @profile.select(:chunk, param_config.select_many.role, :chunk_size => param_config.select_many.chunk_size, :chunk_key => context, :from => from)

    else
      param_config
    end
  end

  def verify_configs
    @roles_config.each do |name, config|
      verify_config(name, config, "role definition")
    end

    @profile.profile_config.each do |name, config|
      verify_config(name, config, "profile role")
    end
  end

  private

  def verify_config(name, config, scope = '')
    return unless config.respond_to? :configurations

    Trollop::die "empty or non-array configurations for #{scope} '#{name}'" unless config.configurations.respond_to? :each

    config.configurations.each do |configuration|
      Trollop::die "nil configuration for #{scope} '#{name}'" unless configuration
      Trollop::die "nameless configuration [#{configuration.to_hash.inspect}] for #{scope} '#{name}'" if configuration.name.to_s.empty?
    end
  end

  def queue_ssh_action(instance, &block)
    @ssh_actions[instance] << block
  end

  def print_ensured_output(threads)
    info "\n"
    threads.each do |t|
      pretty_describe_heading(t[:title])
      t[:ensured_output].each do |method, message|
        send(method, message)
      end

      pretty_describe_footer
    end
  end

  def ensure_output method, message
    Thread.current[:ensured_output] << [method.to_sym, message]
  end
end