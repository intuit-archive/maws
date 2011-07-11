#!/usr/local/bin/ruby

require './lib/lcec2'
require './lib/cap'

#Configuration
#place where the capistrano env files go

CAPISTRANO_ENVFILE_DIR = "../deploy/envfiles"
CAPISTRANO_UPLOAD_DIR = "../deploy/upload"

PEM_PATH = ENV["AWS_PEM_PATH"]

APPS_PER_WEB = 5


def list_instances(ecc, instances, args)
  instances.each_with_index do |i, index|
    puts "**** INSTANCE #{index} ****"
    puts i.to_s
    puts "***********************"
  end
end


def get_web_proxy_config(ecc, instances, args)
  ws_num = 1
  app_count = 0
  proxy_config = Array.new
  
  apps = ecc.get_app_instances(instances, "running")
  webs = ecc.get_web_instances(instances, "running")

  # TODO: remove non-running instances from apps and webs
  
  # sort by the number appended to the name
  apps.sort! {|a,b| a.name[3..-1].to_i <=> b.name[3..-1].to_i}
  webs.sort! {|a,b| a.name[3..-1].to_i <=> b.name[3..-1].to_i}
  
  if webs.size * APPS_PER_WEB != apps.size
    puts "Environment Imbalance Error: there must be #{APPS_PER_WEB} app servers for each web server. Currently there are #{webs.size} webs and #{apps.size} apps"
    return nil
  end
  
  app_index = 0

  webs.each_with_index do |web_instance, index|
    proxy_config[index] = Hash.new
    proxy_config[index][:name] = web_instance.name
    proxy_config[index][:private_dns] = web_instance.private_dns_name
    
    proxy_config[index][:apps] = Array.new
    APPS_PER_WEB.times do
      proxy_config[index][:apps] << "# #{apps[app_index].name} \n BalancerMember http://#{apps[app_index].private_dns_name}:8080"
      app_index += 1
    end
  end

  return proxy_config
end

def create_web_proxy_config(ecc, instances, args)
  unless File.exists?(CAPISTRANO_UPLOAD_DIR)
    puts "Capistrano Upload Directory must already exist: #{CAPISTRANO_UPLOAD_DIR}"
    return
  end
  
  webs = get_web_proxy_config(ecc, instances, args)
  webs.each do |w|
    #CAPISTRANO_UPLOAD_DIR: root directory of capistrano uploads 
    #server_name: directory under upload_dir where an individual server will get its 'stuff', created when the ec2 info is parsed
    #file_name: the name of the file you are creating and will get uploaded
    server_name = w[:private_dns]
    file_name = "proxy.conf"
    file_dir = "#{CAPISTRANO_UPLOAD_DIR}/#{server_name}"
    proxy_file_name = "#{file_dir}/#{file_name}"
    
    begin
      File.delete(proxy_file_name) if File.exists?(proxy_file_name)
      Dir.mkdir(file_dir) unless File.exists?(file_dir)
      
      proxy_file = File.new(proxy_file_name, "w")
      proxy_file.puts "# #{w[:name]}\n# Proxy Balancer: The app servers below will get requests from this web server, fishizzle!\n#\n<Proxy balancer://turbotax_cluster>\n"
      w[:apps].each do |line|
        proxy_file.puts " " + line
      end
      proxy_file.puts "</Proxy>"
      proxy_file.close
      puts `cat #{proxy_file_name}`
    rescue => ex
      puts "Exception writing file: #{ex.inspect}"
    end
  end
  create_envfile(ecc, instances, "amazon-perf")
  upload_vhost(ecc, instances)
  cap "control:restart_apache", "amazon-perf"
end

def print_database_configs(ecc, instances, args)
  dbs = ecc.get_rds_instances
  
end

def print_ssh_commands(ecc, instances, args)
  puts "SSH commands (apps)"
  LcAws.print_ssh_commands(ecc.get_app_instances(instances))

  puts "SSH commands (loadgen)"
  LcAws.print_ssh_commands(ecc.get_loadgen_instances(instances))
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

def show_apps(ecc, instances, args)
  apps = ecc.get_app_instances(instances)
  apps.each do |app|
        puts app.name + " : " + app.state
  end
end

def open_app_terminals(ecc, instances, args)
  servers = ecc.get_app_instances(instances)
  servers.each do |app|
    if app.running?
      cmd = ""
      if app.keyname != "mattinasi"
        cmd =  "ssh -i intuit-baseline.pem ea@#{app.dns_name}"
      else
        cmd =  "ssh -i #{app.keyname}.pem root@#{app.dns_name}"
      end
      puts "opening terminal as: #{cmd}"
      `scripts/it #{cmd}`
    end
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

def show_loadgens(ecc, instances, args)
  puts "Current loadgens servers:"
  servers = ecc.get_loadgen_instances(instances)
  servers.each do |lg|
    puts lg.name + " : " + lg.state
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

def scp_loadgen_results(ecc, instances, args)
  servers = ecc.get_loadgen_instances(instances)
  servers.each do |lg|
    if lg.running?
      cmd =  "scp -i ~/mattinasi.pem root@#{lg.dns_name}:/home/loaduser/performance_result.log #{lg.name}.performance_result.log"
      puts "executing: #{cmd}"
      `#{cmd}`
    end
  end
end

def open_loadgen_terminals(ecc, instances, args)
  servers = ecc.get_loadgen_instances(instances)
  servers.each do |lg|
    if lg.running?
      cmd =  "ssh -i ~/mattinasi.pem root@#{lg.dns_name}"
      puts "opening terminal as: #{cmd}"
      `scripts/it #{cmd}`
    end
  end
end

def open_web_terminals(ecc, instances, args)
  servers = ecc.get_web_instances(instances)
  servers.each do |w|
    if w.running?
      cmd =  "ssh -i ~/mattinasi.pem root@#{w.dns_name}"
      puts "opening terminal as: #{cmd}"
      `scripts/it #{cmd}`
    end
  end
end

def create_envfile(ecc, instances, args)
  args[1].nil? ? community = "amazon-perf" : community = args[1]
  #this will create the capistrano envfile for the current EC2 environment so we can send commands
  #prep the envfile
  puts "Creating envfile for #{community}:"
  envfile_name = "#{CAPISTRANO_ENVFILE_DIR}/#{community}.rb"
  File.delete(envfile_name) if File.exists?( envfile_name)
  #TODO: some exception handling here cause its good to the last drop....
  envfile = File.new(envfile_name, "w")
  web = ecc.get_web_instances
  app = ecc.get_app_instances
  
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


def print_usage
#   puts self.public_methods.sort
#  puts "USAGE: ruby lcaws.rb [list][web-proxy][ssh-commands][stop-apps][start-apps][show-apps][open-apps][stop-loadgens][start-loadgens][show-loadgens][open-loadgens][open-webs][show-dbs][scp-loadgen-results][create-envfile]\n"+
 #      "  There should be at least one command. If more than one command is specified then commands are executed in order"
end

###############
# Script Start
###############
if ARGV.size < 1
  print_usage
else
  ecc = LcAws.new
  instances = ecc.get_instances
  send(ARGV[0],ecc,instances, ARGV) 
end
