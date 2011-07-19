#!/usr/local/bin/ruby

require './lib/lcec2'
require './lib/cap'
require './lib/config'

#Configuration
#place where the capistrano env files go

CAPISTRANO_ENVFILE_DIR = "../deploy/envfiles"
CAPISTRANO_UPLOAD_DIR = "../deploy/upload"

#TODO: This needs refactoring for multiple communities but pulling it out for temp security.
DB_USERNAME = ENV["DB_USERNAME"]
DB_PASSWORD = ENV["DB_PASSWORD"]

PEM_PATH = ENV["AWS_PEM_PATH"]

APPS_PER_WEB = 6
APPS_PER_DB =  12


#this will create the capistrano envfile for the current EC2 environment so we can send commands
def create_envfile(ecc, instances, args)
  args[1].nil? ? community = "amazon-perf" : community = args[1]
  #prep the envfile
  puts "Creating envfile for #{community}:"
  envfile_name = "#{CAPISTRANO_ENVFILE_DIR}/#{community}.rb"
  File.delete(envfile_name) if File.exists?( envfile_name)
  #TODO: some exception handling here cause its good to the last drop....
  envfile = File.new(envfile_name, "w")
  web = ecc.get_web_instances(instances, "running")
  app = ecc.get_app_instances(instances, "running")
  
  envfile.puts "set :community, '#{community}'"
  web_str = ""
  web.each_with_index do |i, index|
     web_str = web_str + "\"" + i.private_dns_name + "\"," unless i.private_dns_name.nil?
  end
  web_str.chomp!(",")
  app_str = ""
  app.each_with_index do |i, index|
     app_str = app_str + "\"" + i.private_dns_name + "\"," unless i.private_dns_name.nil?
  end
  app_str.chomp!(",")
  envfile.puts "role :web, " + web_str
  envfile.puts "role :app, " + app_str
  envfile.close
  puts "Finished creating envfile in #{envfile_name}"
  puts `cat #{envfile_name}`
end




def list_instances(ecc, instances, args)
  throw "instances param cannot be nil" if instances.nil?
  if args[1] != nil
    state = args[1]
  end
  counter = 1
  instances.each do |i|
    if state.nil? || state == i.state
      puts "**** INSTANCE #{counter} ****"
      puts i.to_s
      puts "***********************"
      counter += 1
    end
  end
end

def stop_apps(ecc, instances, args)
  puts "Stopping all app servers..."
  ecc.stop_app_servers
  puts "Done."
end

def start_apps(ecc, instances, args)
  puts "Starting all app servers..."
  ecc.start_app_servers
  puts "Done."
end

# args[1] is an optional state filter: nil means all states, otherwise it can be "running" or "stopped"
def show_apps(ecc, instances, args)
  if args[1] != nil
    state = args[1]
  end
  apps = ecc.get_app_instances(instances, state)
  apps.each do |app|
        puts app.name + " : " + app.state
  end
end

def open_app_terminals(ecc, instances, args)
  servers = ecc.get_app_instances(instances, "running")
  counter = 1
  servers.each do |app|
    cmd =  "ssh -i intuit-baseline.pem ea@#{app.dns_name}"
    puts "opening terminal #{counter} as: #{cmd}"
    `scripts/it #{cmd}`
    sleep 1
    counter += 1
  end
end

def stop_loadgens(ecc, instances, args)
  puts "Stopping all loadgen servers..."
  ecc.stop_loadgen_servers
  puts "Done."
end

def start_loadgens(ecc, instances, args)
  puts "Starting all loadgens servers..."
  ecc.start_loadgen_servers
  puts "Done."
end

# args[1] is an optional state filter: nil means all states, otherwise it can be "running" or "stopped"
def show_loadgens(ecc, instances, args)
  if args[1] != nil
    state = args[1]
  end
  puts "Current loadgens servers:"
  servers = ecc.get_loadgen_instances(instances, state)
  servers.each do |lg|
    puts lg.name + " : " + lg.state
  end
end

def stop_webs(ecc, instances, args)
  puts "Stopping all web servers..."
  ecc.stop_web_servers
  puts "Done."
end

def start_webs(ecc, instances, args)
  puts "Starting all web servers..."
  ecc.start_web_servers
  puts "Done."
end

# args[1] is an optional state filter: nil means all states, otherwise it can be "running" or "stopped"
def show_webs(ecc, instances, args)
  if args[1] != nil
    state = args[1]
  end
  webs = ecc.get_web_instances(instances, state)
  webs.each do |web|
        puts web.name + " : " + web.state
  end
end

def scp_loadgen_results(ecc, instances, args)
  servers = ecc.get_loadgen_instances(instances)
  servers.each do |lg|
    if lg.running?
      cmd =  "scp -i ~/intuit-baseline.pem ea@#{lg.dns_name}:/home/loaduser/performance_result.log #{lg.name}.performance_result.log"
      puts "executing: #{cmd}"
      `#{cmd}`
    end
  end
end

def open_loadgen_terminals(ecc, instances, args)
  servers = ecc.get_loadgen_instances(instances, "running")
  counter = 0
  servers.each do |lg|
    cmd =  "ssh -i ~/intuit-baseline.pem ea@#{lg.dns_name}"
    puts "opening terminal #{counter} as: #{cmd}"
    `scripts/it #{cmd}`
    counter += 1
    sleep 1
  end
end

def open_web_terminals(ecc, instances, args)
  servers = ecc.get_web_instances(instances, "running")
  counter = 0
  servers.each do |w|
    cmd =  "ssh -i intuit-baseline.pem ea@#{w.dns_name}"
    puts "opening terminal #{counter} as: #{cmd}"
    `scripts/it #{cmd}`
    counter += 1
    sleep 1
  end
end

def show_dbs(ecc, instances, args)
  puts "Current Database Instances:"
  dbs = ecc.get_rds_instances
  dbs.each do |db|
    puts db.to_s
    puts ' '
  end
end

def show_availability_zones(ecc, instances, args)
  zones = ecc.get_availability_zones
  zones.each do |zone|
    puts "Availalability Zone: #{zone["zoneName"]} : #{zone["zoneState"]}"
  end  
end

def validate_servers(ecc, instances, args)
#a check validation for all servers
  web = ecc.get_web_instances(instances, "running")
  app = ecc.get_app_instances(instances, "running")
  servers = web | app
  puts "Validating Servers"
  status = Array.new
  servers.each do |current_server|
    begin
      printf "."
      #check one make sure the server has a private dns
      private_name = current_server.private_dns_name
      #check to make sure the server has a public dns
      public_name = current_server.dns_name
 
      #connect via ssh and run hostname to validate connection
      private_ping = system "ssh #{private_name} hostname > /dev/null 2>&1"
      puts "Private Ping failed for #{current_server.name}" if !private_ping
 
      #connect cia ssh and rub hostname on validate connection
      public_ping = system "ssh #{public_name} hostname > /dev/null 2>&1"
      puts "Private Ping Failed for #{current_server.name}" if !public_ping
      #gather the data!! 
      status << [private_name, public_name, private_ping, public_ping]
    rescue
      puts "Something nasty happened"
      status << [private_name.to_s, public_name.to_s, private_ping.to_s, public_ping.to_s]
    end
  end
  puts "."
  status.each { |a,b,c,d| puts a + "::" + b + "::" + c.to_s + "::" + d.to_s}
  puts "Validated complete: [#{servers.size}] checked"
end

def print_usage
 puts "USAGE: ruby lcaws.rb <command>"
 puts "where <command> is one of the following methods: \n"+
       " create_envfile, update_web_configs, update_database_configs, \n"+
       " start_apps, stop_apps, show_apps, open_app_terminals, \n" +
       " start_loadgens, stop_loadgens, open_loadgen_termials, \n"+
       " start_webs, stop_webs, show_webs, open_web_terminals\n"+
       " show_dbs, list_instances"
end

###############
# Script Start
###############
if ARGV.size < 1
  print_usage
else
  ecc = LcAws.new
  instances = ecc.get_instances
  
  begin
    send(ARGV[0],ecc,instances, ARGV) 
  rescue => ex
    puts "Error running command: #{ex.inspect}"
  end
end
