require 'yaml'

require 'maws/maws'

require 'maws/profile_loader'
require 'maws/command_loader'

require 'maws/command_options_parser'

class Loader

  def initialize(base_path, config_config_path)
    @base_path = base_path
    @cc_path = config_config_path
    @commands_path = File.expand_path("commands/", File.dirname(__FILE__))

    # stores all config
    @config = mash
    @command = nil

    Loader.config_file_must_exist!('main', @cc_path)

    @command_options_parser = CommandOptionsParser.new(@config)
  end

  def load_and_run
    load_config
    load_command
    initialize_command

    parse_command_line_options
    verify_command

    @maws = Maws.new(@config, @command)
    @command.maws = @maws

    @maws.run!
  end

  private

  def load_config
    @config.config = mash(YAML.load_file(@cc_path))

    @config.config.paths.commands = @commands_path
    @config.config.paths.base = @base_path
    @config.config.paths.config = @cc_path
    @config.config.paths.template_output = 'tmp/'

    expand_config_paths

    load_aws_key
    glob_available_profiles_and_commands
    read_core_command_line_options
    exit_with_basic_help_usage if needs_basic_help_usage?
    exit_on_missing_profile
    exit_on_missing_command

    ProfileLoader.new(@config).load
  end

  def load_command
    CommandLoader.new(@config).load
  end

  def initialize_command
    @command = @config.command_class.new(@config)
  end

  def parse_command_line_options
    @command_options_parser.process_command_options(@command)
    @command.process_options
  end

  def verify_command
    @command.verify_options
    @command.verify_configs
  end

  def load_aws_key
    Loader.config_file_must_exist!('aws_key', @config.config.paths.aws_key)

    @config.aws_key = mash

    key_id, secret_key = *File.read(@config.config.paths.aws_key).lines.map {|l| l.chomp}
    @config.aws_key.key_id = key_id
    @config.aws_key.secret_key = secret_key
  end

  def glob_available_profiles_and_commands
    available_profiles = mash
    available_commands = mash

    Dir.glob(@config.config.paths.profiles + '/*.yml').each {|path|
      name = File.basename(path,'.yml')
      available_profiles[name] = path
    }

    Dir.glob(@config.config.paths.commands + '/*.rb').each {|path|
      name = File.basename(path,'.rb')
      available_commands[name] = path
    }

    @config.config.available_profiles = available_profiles
    @config.config.available_commands = available_commands
  end

  def read_core_command_line_options
    @config.command_line = mash
    @config.command_line.profile_name = ARGV.shift
    @config.command_line.command_name = ARGV.shift
  end

  def needs_basic_help_usage?
    profile_name = @config.command_line.profile_name
    command_name = @config.command_line.command_name

    profile_name.blank? ||
    command_name.blank? ||
    profile_name == '-h' ||
    profile_name == '--help' ||
    command_name == '-h' ||
    command_name == '--help'
  end

  def exit_with_basic_help_usage
    profile_name = @config.command_line.profile_name
    command_name = @config.command_line.command_name

    profile_name = nil if profile_name == '-h' || profile_name == '--help'
    command_name = nil if command_name == '-h' || command_name == '--help'

    exit_with_basic_usage(profile_name, command_name)
  end

  def exit_on_missing_profile
    profile_name = @config.command_line.profile_name

    if @config.config.available_profiles[profile_name].blank?
      puts "ERROR: no such profile: #{profile_name}"
      exit_with_basic_usage(profile_name, @config.command_line.command_name)
    end
  end

  def exit_on_missing_command
    command_name = @config.command_line.command_name

    if @config.config.available_commands[command_name].blank?
      puts "ERROR: no such command: #{command_name}"
      exit_with_basic_usage(@config.command_line.profile_name, command_name)
    end
  end

  def exit_with_basic_usage(profile_name, command_name)
    puts @command_options_parser.usage(profile_name, command_name)
    exit(1)
  end

  def expand_config_paths
    base_path = @config.config.paths.base
    @config.config.paths.each { |path_name, path_location|
      @config.config.paths[path_name] = File.expand_path(path_location, base_path)
    }
  end

  def self.config_file_must_exist!(name, path)
    unless File.exists? path
      error "No #{name} config: #{path} found. Quiting!"
      exit(1)
    end
  end

end