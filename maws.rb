#!/usr/bin/env ruby

require 'rubygems'
require 'hashie'

require 'lib/command_parser'
require 'lib/aws_connection'


begin
  # optional awesome print
  require 'ap'
rescue LoadError
  def ap(x)
    p x
  end
end

def symbolize(*names)
  names.map {|n| n.to_sym}
end

CONFIG_CONFIG_PATH = 'config/config.yml'

unless File.exists? CONFIG_CONFIG_PATH
  $stderr.puts "No main config file: #{CONFIG_CONFIG_PATH} found. Quiting!"
  exit(1)
end

cc = YAML.load_file(CONFIG_CONFIG_PATH)

BASE_PATH = File.dirname(__FILE__)


AWS_KEY_PATH = File.expand_path(cc["aws_key_path"], BASE_PATH)
KEYPAIRS_PATH = File.expand_path(cc["keypairs_path"], BASE_PATH)
PROFILES_PATH = File.expand_path(cc["profiles_path"], BASE_PATH)
ROLES_PATH = File.expand_path(cc["roles_path"], BASE_PATH)
SECURITY_RULES_PATH = File.expand_path(cc["security_rules_path"], BASE_PATH)

TEMPLATES_PATH = File.expand_path(cc["templates_path"], BASE_PATH)

COMMANDS_PATH = BASE_PATH + '/lib/commands'

unless File.exists? AWS_KEY_PATH
  $stderr.puts "No AWS secret key file: #{AWS_KEY_PATH}"
  exit
end
KEY_ID,SECRET_KEY = *File.read(AWS_KEY_PATH).lines.map {|l| l.chomp}

cp = CommandParser.new(PROFILES_PATH, ROLES_PATH, COMMANDS_PATH, SECURITY_RULES_PATH, cc["default_region"], cc["default_zone"])
command = cp.parse_and_load_command()
command.connection = AwsConnection.new(KEY_ID, SECRET_KEY, command.options)
command.sync_profile_instances
command.run!


# generate security group names based on profile/role
# destroy EBS for when destroying EC2 (RightAWS::EC2#delete_volume)