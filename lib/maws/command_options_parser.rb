require 'maws/trollop'

class CommandOptionsParser
  def initialize(config)
    @config = config
  end

  def process_command_options(command)
    banner_text = usage(@config.profile.name, @config.command_name)
    banner_text << "\n#{command.description}\n\n"
    banner_text << "options:\n"
    command_opts = Trollop::options do
      banner banner_text
      command.add_generic_options(self)
      command.add_specific_options(self)
    end

    @config.command_line.merge!(command_opts)
  end

  def usage(profile = nil, command = nil)
    profile ||= 'profile'
    command ||= 'command'
    <<-EOS

MAWS - Toolset for provisioning and managing AWS

Usage:
       maws.rb #{profile} #{command} [options]

profiles: #{@config.config.available_profiles.keys.join(', ')}
commands: #{@config.config.available_commands.keys.join(', ')}

    EOS
  end

end