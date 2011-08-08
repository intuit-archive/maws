#!/usr/bin/env ruby

require 'rubygems'
require 'right_aws'
require 'hashie'

require 'lib/command_parser'

BASE_PATH = File.dirname(__FILE__)
PROFILES_PATH = BASE_PATH + '/config/profiles'
ROLES_PATH = BASE_PATH + '/config/roles'
COMMANDS_PATH = BASE_PATH + '/lib/commands'

cp = CommandParser.new(PROFILES_PATH, ROLES_PATH,COMMANDS_PATH)
# cp.load_profile_config
# cp.load_roles_config
cp.run!