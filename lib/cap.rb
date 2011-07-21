#lcec2 support for capistrano commands

CAPISTRANO_ENVFILE_DIR = "../deploy/envfiles"
CAPISTRANO_UPLOAD_DIR = "../deploy/upload"

#cap control:check_all_ok                      # Checks /app/check_response on...
#cap control:create_search_indices             # Create the search indices
#cap control:restart_apache                    # Restart Apache
#cap control:restart_unicorn                   # Restart unicorn
#cap control:show_servers_in_role              # Show the servers in the reque...
#cap control:start_apache                      # Start Apache
#cap control:start_memcached                   # Start memcached
#cap control:start_search                      # Start Solr
#cap control:start_unicorn                     # Start Unicorn
#cap control:stat_apache                       # Stat Apache
#cap control:stat_memcached                    # Stat memcached
#cap control:stat_search                       # Stat Solr
#cap control:stat_unicorn                      # Stat Unicorn
#cap control:stop_apache                       # Stop Apache
#cap control:stop_memcached                    # Stop memcached
#cap control:stop_search                       # Stop Solr
#cap control:stop_unicorn                      # Stop Unicorn

#we will need to pass the community in the future. Default is set for dev purposes.

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


def check_all_ok(ecc, instances, args)
  args[1].nil? ? community = "amazon-perf" : community = args[1]
  cap("control:stat_unicorn", community)
end

def restart_apache(ecc, instances, args)
  args[1].nil? ? community = "amazon-perf" : community = args[1]
  cap "control:restart_apache", community
end

def restart_unicorn(ecc, instances, args)
  args[1].nil? ? community = "amazon-perf" : community = args[1]
  cap "control:restart_unicorn", community
end

def stop_unicorn(ecc, instances, args)
  args[1].nil? ? community = "amazon-perf" : community = args[1]
  cap "control:stop_unicorn", community
end

def start_unicorn(ecc, instances, args)
  args[1].nil? ? community = "amazon-perf" : community = args[1]
  cap "control:start_unicorn", community
end

def stat_unicorn(ecc, instances, args)
  args[1].nil? ? community = "amazon-perf" : community = args[1]
  cap "control:stat_unicorn", community
end
def stop_search(ecc, instances, args)
  args[1].nil? ? community = "amazon-perf" : community = args[1]
  cap "control:stop_search", community
end

def start_search(ecc, instances, args)
  args[1].nil? ? community = "amazon-perf" : community = args[1]
  cap "control:start_search", community
end

def start_memcached(ecc, instances, args)
  args[1].nil? ? community = "amazon-perf" : community = args[1]
  cap "control:start_memcached", community
end

#example of calling hostname on a specific server. The community is uneccesary if calling by server name.
def hostname(ecc, instances, args)
  args[1].nil? ? community = "amazon-perf" : community = args[1]
  args[2].nil? ? server = nil : server = args[2]
  cap("control:hostname", community, server)
end

def upload_vhost(ecc, instances)
   #get active web servers...
   web =  ecc.get_web_instances(instances, "running")
   #individually upload vhost files
   web.each do |x|
      name = x.private_dns_name
      `scp ../deploy/upload/#{name}/proxy.conf #{name}:.` 
   end
   cap "control:move_vhost", "amazon-perf"
end

def upload_database_yml(ecc, instances)
   #get active web servers...
   servers = ecc.get_app_layer_instances(instances)
   #individually upload vhost files
   servers.each do |x|
      name = x.private_dns_name
      `scp ../deploy/upload/#{name}/database.yml #{name}:.`
   end
   cap "control:move_database_yml", "amazon-perf"
end

def upload_app_conf(ecc, instances)
   #get active web servers...
   servers = ecc.get_app_layer_instances(instances) 
   #individually upload vhost files
   servers.each do |x|
      name = x.private_dns_name
      `scp ../deploy/upload/#{name}/remote_dependencies.rb #{name}:.`
   end
   cap "control:move_app_conf", "amazon-perf"
end


private 

def cap(command, community, server = nil)
  server.nil? ? server = "" : server = "HOSTS=#{server}"
  puts `cd ../deploy; cap #{server}  #{command} deploy_env=#{community}`
end
