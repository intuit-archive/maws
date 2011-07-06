#lcec2 wrappers for cap commands

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

def check_all_ok(ecc, instances, community = 'amazon-perf')
  cap("control:stat_unicorn", community)
end

def restart_apache(ecc, instances, community = 'amazon-perf')
  cap "control:restart_apache, community"
end

def restart_unicorn(ecc, instances, community = 'amazon-perf')
  cap "control:restart_unicorn, community"
end

def start_memcached(ecc, instances, community = 'amazon-perf')
  cap "control:start_memcached, community"
end

def hostname(ecc, instances, community = 'amazon-perf', server = nil)
  cap("control:hostname", community, "ip-10-2-250-145.ec2.internal")
end
 
private 
  
def cap(command, community, server = nil)
  server.nil? ? server = "" : server = "HOSTS=#{server}"
  puts `cd ../deploy; cap #{server}  #{command} deploy_env=#{community}`
end
