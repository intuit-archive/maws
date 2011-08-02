#!/usr/local/bin/ruby

require './lib/lcec2'
require './lib/cap'
require './lib/config'

PEM_PATH = ENV["AWS_PEM_PATH"]

APPS_PER_WEB = 6
APPS_PER_DB =  12


def show_instances(ecc, instances, args)
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

def show_dbs(ecc, instances, args)
  puts "Current Database Instances:"
  dbs = ecc.get_rds_instances
  dbs.each do |db|
    puts db.to_s
    puts ' '
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

def start_services(ecc, instances, args)
  puts "Starting all services servers..."
  ecc.start_service_servers
  puts "Done."
end

def stop_services(ecc, instances, args)
  puts "Stopping all services servers..."
  ecc.stop_service_servers
  puts "Done."
end

def show_services(ecc, instances, args)
  if args[1] != nil
    state = args[1]
  end
  svcs = ecc.get_service_instances(instances, state)
  svcs.each do |s|
        puts s.name + " : " + s.state
  end
end

def start_searches(ecc, instances, args)
  puts "Starting all search servers..."
  ecc.start_search_servers
  puts "Done."
end

def stop_searches(ecc, instances, args)
  puts "Stopping all search servers..."
  ecc.stop_search_servers
  puts "Done."
end

def show_searches(ecc, instances, args)
  if args[1] != nil
    state = args[1]
  end
  searches = ecc.get_search_instances(instances, state)
  searches.each do |s|
        puts s.name + " : " + s.state
  end
end

def start_queues(ecc, instances, args)
  puts "Starting all queue servers..."
  ecc.start_queue_servers
  puts "Done."
end

def stop_queues(ecc, instances, args)
  puts "Stopping all queue servers..."
  ecc.stop_queue_servers
  puts "Done."
end

def show_queues(ecc, instances, args)
  if args[1] != nil
    state = args[1]
  end
  queues = ecc.get_queue_instances(instances, state)
  queues.each do |s|
        puts s.name + " : " + s.state
  end
end

def start_caches(ecc, instances, args)
  puts "Starting all cache servers..."
  ecc.start_cache_servers
  puts "Done."
end

def stop_caches(ecc, instances, args)
  puts "Stopping all cache servers..."
  ecc.stop_cache_servers
  puts "Done."
end

def show_caches(ecc, instances, args)
  if args[1] != nil
    state = args[1]
  end
  caches = ecc.get_search_instances(instances, state)
  caches.each do |s|
        puts s.name + " : " + s.state
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

#
# terminal operations
#

def open_web_terminals(ecc, instances, args)
  servers = ecc.get_web_instances(instances, "running")
  open_terminals(servers)
end

def open_app_terminals(ecc, instances, args)
  servers = ecc.get_app_instances(instances, "running")
  open_terminals(servers)
end

def open_loadgen_terminals(ecc, instances, args)
  servers = ecc.get_loadgen_instances(instances, "running")
  open_terminals(servers)
end

def open_service_terminals(ecc, instances, args)
  servers = ecc.get_service_instances(instances, "running")
  open_terminals(servers)
end

def open_terminals(servers)
  counter = 0
  servers.each do |s|
    cmd =  "ssh -i intuit-baseline.pem ea@#{s.dns_name}"
    puts "opening terminal #{counter} as: #{cmd}"
    `scripts/it #{cmd}`
    counter += 1
    sleep 1
  end
end

def open_terminal(ecc, instances, args)
  name = args[1]
  servers = Array.new
  instances.each do |s|
    servers << s if s.name == name
  end
  open_terminals(servers)
end

def show_availability_zones(ecc, instances, args)
  zones = ecc.get_availability_zones
  zones.each do |zone|
    puts "Availalability Zone: #{zone["zoneName"]} : #{zone["zoneState"]}"
  end  
end

def validate_servers(ecc, instances, args)
  skip_private_ip = args[1] == "skip_private_ip"
  puts "skipping private-ip check" if skip_private_ip
  
#a check validation for all servers
  web = ecc.get_web_instances(instances, "running")
  app_layer = ecc.get_app_layer_instances(instances, "running")
  servers = web | app_layer

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
      unless skip_private_ip
        private_ping = system "ssh #{private_name} hostname > /dev/null 2>&1"
        puts "Private Ping failed for #{current_server.name}" if !private_ping
      end
      
      #connect cia ssh and rub hostname on validate connection
      public_ping = system "ssh #{public_name} hostname > /dev/null 2>&1"
      puts "Public Ping Failed for #{current_server.name}" if !public_ping
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
       " show_dbs, list_instances, validate_servers"
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
    puts ex.backtrace
  end
end
