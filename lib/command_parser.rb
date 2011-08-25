require 'yaml'
require 'lib/profile'

require 'lib/logger'
require 'lib/trollop'


class CommandParser
  attr_reader :available_profiles

  def initialize(profiles_path, roles_path, commands_path)
    @profiles_path = profiles_path
    @roles_path = roles_path
    @commands_path = commands_path

    @available_profiles = Dir.glob(@profiles_path + '/*.yml').collect {|p| File.basename(p,'.yml')}
    @available_commands = Dir.glob(@commands_path + '/*.rb').collect {|p| File.basename(p,'.rb')}
  end

  def parse_and_load_command
    try_generic_help_message

    detect_selected_profile
    detect_selected_command

    if File.exists?(@selected_profile_path) && File.exists?(@selected_command_path)
      # parse configs
      load_profile_config

      # parse command options if the command is available
      load_selected_command
      @command = @command_klass.new(@profile, @roles)
      process_command_options
      @profile.build_instance_objects
      verify_profile
      @command.verify_options
    else
      # print usage information and an error message
      ARGV.delete_if {|arg| arg != "-h" && arg != "--help"}
      process_generic_help_options
      Trollop::die "no such profile #{@selected_profile_path}" unless File.exists?(@selected_profile_path)
      Trollop::die "no such command #{@selected_command}" unless File.exists? @selected_command_path
    end

    @command
  end

  def load_profile_config
    @profile_config = mash(YAML.load_file(@selected_profile_path))
    @profile_config.name = @selected_profile

    load_roles_config
    @profile = Profile.new(@profile_config, @roles)
  end

  def load_roles_config
    roles_config_path = @roles_path + "/#{@profile_config.roles}.yml"
    unless File.exists? roles_config_path
      error "profile #{@profile.name} config file is broken - can't find roles file #{roles_config_path}"
      exit
    end

    @roles = mash(YAML.load_file(roles_config_path))
    @roles.keys.each {|name| @roles[name].name = name}
  end

  def detect_selected_profile
    @selected_profile = ARGV.shift
    @selected_profile_path = @profiles_path + "/#{@selected_profile}.yml"
  end

  def detect_selected_command
    @selected_command = ARGV.shift
    @selected_command_path = @commands_path + "/#{@selected_command}.rb"
  end

  def load_selected_command
    require @selected_command_path
    @command_klass = Object.const_get(humanize(@selected_command.capitalize))
  end

  def verify_profile
    unless @profile.missing_role_names.empty?
      Trollop::die "Undefined roles [%s] in profile '%s'" % [@profile.missing_role_names.join(', '), @profile.name]
    end
  end

  private

  def humanize(dashed)
    dashed.split('-').map {|w| w.capitalize}.join
  end

  def try_generic_help_message
    # print help when no commands given
    if ARGV.empty?
      ARGV << "-h"
      process_generic_help_options
    end

    if (ARGV.include?('-h') || ARGV.include?('--help')) && ARGV.length < 3
      # we don't have enough info to print command help - use generic help
      process_generic_help_options
    end
  end

  def process_generic_help_options
    banner_text = usage
    Trollop::options do
      banner banner_text
      stop_on @available_profiles # only parse the profile
    end
  end

  def process_command_options
    banner_text = usage(@selected_profile, @selected_command)
    banner_text << "options:\n"
    command = @command
    command_opts = Trollop::options do
      banner banner_text
      command.add_generic_options(self)
      command.add_specific_options(self)
    end
    command_opts[:availability_zone] = command_opts[:region] + command_opts[:zone]

    @command.options = mash command_opts
    @profile.command_options = @command.options
  end

  def usage(profile='profile', command='command')
    <<-EOS
Generic AWS Management Scripts

Usage:
       maws.rb #{profile} #{command} [options]

profiles: #{@available_profiles.join(', ')}
commands: #{@available_commands.join(', ')}

    EOS
  end

end