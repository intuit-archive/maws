#!/usr/local/bin/ruby

require './lib/lcec2'
require './lib/cap'

#Configuration
#place where the capistrano env files go

CAPISTRANO_ENVFILE_DIR = "../deploy/envfiles"
CAPISTRANO_UPLOAD_DIR = "../deploy/upload"

PEM_PATH = ENV["AWS_PEM_PATH"]

APPS_PER_WEB = 6
APPS_PER_DB =  12


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
  
  # get running web and app instances
  apps = ecc.get_app_instances(instances, "running")
  webs = ecc.get_web_instances(instances, "running")
  
  # sort by the number appended to the name
  apps.sort! {|a,b| a.name[3..-1].to_i <=> b.name[3..-1].to_i}
  webs.sort! {|a,b| a.name[3..-1].to_i <=> b.name[3..-1].to_i}
  
  # make sure the ration of web to apps is correct
  if webs.size * APPS_PER_WEB != apps.size
    puts "Environment Imbalance Error: there must be #{APPS_PER_WEB} app servers for each web server. Currently there are #{webs.size} webs and #{apps.size} apps"
    return nil
  end
  
  # allocate the app servers to the web servers
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
  upload_vhost(ecc, instances)
  cap "control:restart_apache", "amazon-perf"
end

def get_database_configs(ecc, instances, args)
  app_num = 1
  db_count = 0
  slave_config = Array.new

  apps = ecc.get_app_instances(instances, "running")
  dbs = ecc.get_rds_instances_by_name("slavedb")
  masterdb = ecc.get_rds_instances_by_name("masterdb")[0]
  session = ecc.get_rds_instances_by_name("session")[0]

  #dbs[0].endpoint_address
  
  # sort by the number appended to the name
  apps.sort! {|a,b| a.name[3..-1].to_i <=> b.name[3..-1].to_i}
  dbs.sort! {|a,b| a.name[3..-1].to_i <=> b.name[3..-1].to_i}

  if dbs.size * APPS_PER_DB != apps.size
    puts "Environment Imbalance Error: there must be #{APPS_PER_DB} app servers for each slave db server. Currently there are #{apps.size} apps and #{dbs.size} slave databases"
    return nil
  end

  database_yml_config = Array.new
  db_loop = 0 #current database server
  set_counter = 1 #current iteration for each database

  apps.each do |app|
     puts "DEBUG: current db = #{db_loop} current app_counter = #{set_counter}"
     database_yml_config << [app.private_dns_name, dbs[db_loop].endpoint_address, masterdb.endpoint_address, session.endpoint_address]
     if set_counter.eql?(APPS_PER_DB) 
        db_loop = db_loop + 1
        set_counter = 0
     end
     set_counter = set_counter + 1
  end

  #database_yml_config.sort! {|a,b| a.name[3..-1].to_i <=> b.name[3..-1].to_i}
  database_yml_config.each do |x|
      puts "app: #{x[0]}, db: #{x[1]}"
      puts "\n"
  end

  return database_yml_config

end

def create_database_configs(ecc, instances, args)
  slave_config = get_database_configs(ecc, instances, args)
  #slave_config.each { |x| puts x.inspect + "\n\n ##########"}    
  slave_config.each do |w|
    #CAPISTRANO_UPLOAD_DIR: root directory of capistrano uploads 
    #server_name: directory under upload_dir where an individual server will get its 'stuff', created when the ec2 info is parsed
    #file_name: the name of the file you are creating and will get uploaded
    server_name = w[0]
    file_name = "database.yml"
    file_dir = "#{CAPISTRANO_UPLOAD_DIR}/#{server_name}"
    db_file_name = "#{file_dir}/#{file_name}"

    begin
      File.delete(db_file_name) if File.exists?(db_file_name)
      Dir.mkdir(file_dir) unless File.exists?(file_dir)
      db_file = File.new(db_file_name, "w")
      db_file.puts "slave: #{w[1]}\n"
      db_file.puts "master: #{w[2]}\n"
      db_file.puts "sesion: #{w[3]}\n"
      db_file.close
      puts `cat #{db_file_name}`
    rescue => ex
      puts "Exception writing file: #{ex.inspect}"
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
      cmd =  "ssh -i intuit-baseline.pem ea@#{w.dns_name}"
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
 puts "USAGE: ruby lcaws.rb <command>"
 puts "where <command> is one of the following methods: \n"+
       " create_envfile, create_web_proxy_config, create_database_configs, list_instances, \n"+
       " start_apps, stop_apps, show_apps, open_app_terminals, \n" +
       " start_loadgens, stop_loadgens, open_loadgen_termials, \n"+
       " start_webs, stop_webs, show_webs, open_web_terminals\n"
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
