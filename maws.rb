#!/usr/bin/env ruby

require 'rubygems'
require 'hashie'

require 'lib/command_parser'
require 'lib/aws_connection'

BASE_PATH = File.dirname(__FILE__)
PROFILES_PATH = BASE_PATH + '/config/profiles'
ROLES_PATH = BASE_PATH + '/config/roles'
COMMANDS_PATH = BASE_PATH + '/lib/commands'

AWS_KEY_FILE = "config/aws.key"
unless File.exists? AWS_KEY_FILE
  $stderr.puts "No AWS secret key file: #{AWS_KEY_FILE}"
  exit
end
KEY_ID,SECRET_KEY = *File.read(AWS_KEY_FILE).lines.map {|l| l.chomp}

cp = CommandParser.new(PROFILES_PATH, ROLES_PATH,COMMANDS_PATH)
command = cp.parse_and_load_command
command.connection = AwsConnection.new(KEY_ID, SECRET_KEY)
command.run!