#!/usr/bin/env ruby

require 'rubygems'
require 'hashie'

require 'lib/command_parser'
require 'lib/aws_connection'

BASE_PATH = File.dirname(__FILE__)
PROFILES_PATH = BASE_PATH + '/config/profiles'
ROLES_PATH = BASE_PATH + '/config/roles'
COMMANDS_PATH = BASE_PATH + '/lib/commands'

unless File.exists? "config/aws.key"
  $stderr.puts "No AWS secret key file: config/aws.key"
  exit
end

KEY_ID,SECRET_KEY = *File.read("config/aws.key").lines

cp = CommandParser.new(PROFILES_PATH, ROLES_PATH,COMMANDS_PATH)
command = cp.parse_and_load_command
command.connection = AwsConnection.new(KEY_ID, SECRET_KEY)
command.run!