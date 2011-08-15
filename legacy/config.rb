#Create the files needed for deployment...

#TODO: This needs refactoring for multiple communities but pulling it out for temp security.
DB_USERNAME = ENV["DB_USERNAME"]
DB_PASSWORD = ENV["DB_PASSWORD"]

#all remote dependencies will go here.
def get_web_proxy_configs(ecc, instances, args)
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

def update_web_configs(ecc, instances, args)
  unless File.exists?(CAPISTRANO_UPLOAD_DIR)
    puts "Capistrano Upload Directory must already exist: #{CAPISTRANO_UPLOAD_DIR}"
    return
  end
  
  webs = get_web_proxy_configs(ecc, instances, args)
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
  service = ecc.get_service_instances(instances, "running")
  search = ecc.get_search_instances(instances, "running")

  dbs = ecc.get_rds_instances_by_name("slavedb")
  servicedbs = ecc.get_rds_instances_by_name("servicedb")[0]
  masterdb = ecc.get_rds_instances_by_name("masterdb")[0]
  session = ecc.get_rds_instances_by_name("session")[0]

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

  #point the service machines to the service slave
  service.each do |service_inst|
    database_yml_config << [service_inst.private_dns_name, servicedbs.endpoint_address, masterdb.endpoint_address, session.endpoint_address]
  end

  #point the search machine to the service slave
  search.each do |search_inst|
    database_yml_config << [search_inst.private_dns_name, servicedbs.endpoint_address, masterdb.endpoint_address, session.endpoint_address]
  end

  #database_yml_config.sort! {|a,b| a.name[3..-1].to_i <=> b.name[3..-1].to_i}
  database_yml_config.each do |x|
      puts "app: #{x[0]}, db: #{x[1]}"
      puts "\n"
  end

  return database_yml_config

end

def update_database_configs(ecc, instances, args)
  db_config = get_database_configs(ecc, instances, args)
  db_config.each do |w|
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
      app_name = w[0] 
      db_slave = w[1]
      db_master = w[2]
      db_session = w[3]

      db_file.puts"#database file for app server #{app_name} (#{Time.now})\n"
      db_file.puts"production:"
      db_file.puts"  adapter: mysql"
      db_file.puts"  database: cia_prod"
      db_file.puts"  username: #{DB_USERNAME}"
      db_file.puts"  password: #{DB_PASSWORD}"
      db_file.puts"  host: #{db_master}"
      db_file.puts"  port: 3306"
      db_file.puts"\n"
      db_file.puts"production_slave_database_1:"
      db_file.puts"  adapter: mysql"
      db_file.puts"  database: cia_prod"
      db_file.puts"  host: #{db_slave}"
      db_file.puts"  username: #{DB_USERNAME}"
      db_file.puts"  password: #{DB_PASSWORD}"
      db_file.puts"  port: 3306"
      db_file.puts"\n"
      db_file.puts"sessions:"
      db_file.puts"  adapter: mysql"
      db_file.puts"  database: sessions"
      db_file.puts"  username: #{DB_USERNAME}"
      db_file.puts"  password: #{DB_PASSWORD}"
      db_file.puts"  host: #{db_session}"
      db_file.puts"  port: 3306"
#      db_file.puts"\n"
#      db_file.puts"cassandra_sessions:"
#      db_file.puts"  #host: ip-10-111-61-76.ec2.internal"
#      db_file.puts"  host: ip-10-38-93-252.ec2.internal"
#      db_file.puts"  port: 9160"

      db_file.close
      puts `cat #{db_file_name}`
    rescue => ex
      puts "Exception writing file: #{ex.inspect}"
    end
  end
  upload_database_yml(ecc, instances)
  #cap "control:stop_unicorn", "amazon-perf"
  #cap "control:start_unicorn", "amazon-perf"
end

def update_app_configs(ecc, instances, args)
  #prep apps
  update_database_configs(ecc, instances, args)
  apps = ecc.get_app_layer_instances(instances, "running")
  
  #prep cache
  cache = ecc.get_cache_instances(instances, "running")
  cache_list = String.new
  cache.each do |server|
    cache_list = cache_list + "\"#{server.private_dns_name}:11211\","
  end
  cache_list.chomp!(",")
  
  #prep search  
  search = ecc.get_search_instances(instances, "running")
  services = ecc.get_service_instances(instances, "running")
  
  puts search.size.to_s + " :search"
  puts services.size.to_s + " :services"
  
  apps.sort! {|a,b| a.name[3..-1].to_i <=> b.name[3..-1].to_i}
  search.sort! {|a,b| a.name[3..-1].to_i <=> b.name[3..-1].to_i}
  services.sort! {|a,b| a.name[3..-1].to_i <=> b.name[3..-1].to_i}
 
  primary_post_server = "http://#{services[0].private_dns_name}:#\{SOLR_PORT\}/solr/posts"
  primary_tag_server =  "http://#{services[0].private_dns_name}:#\{SOLR_PORT\}/solr/tags"
  primary_user_server = "http://#{services[0].private_dns_name}:#\{SOLR_PORT\}/solr/users"

  #primary_search_cluster 
  
  post_server_cluster = String.new
  tag_server_cluster = String.new
  user_server_cluster = String.new
  
  search.each do |server|
    post_server_cluster += "\"" + server.private_dns_name + ":#\{SOLR_PORT\}/solr/posts\","
    tag_server_cluster += "\"" + server.private_dns_name + ":#\{SOLR_PORT\}/solr/tags\","
    user_server_cluster += "\"" + server.private_dns_name + ":#\{SOLR_PORT\}/solr/users\","
  end
  
  post_server_cluster.chomp!(",")
  tag_server_cluster.chomp!(",")
  user_server_cluster.chomp!(",")  


  ################# write it out ##############################

  apps.each do |server|
    #CAPISTRANO_UPLOAD_DIR: root directory of capistrano uploads 
    #server_name: directory under upload_dir where an individual server will get its 'stuff', created when the ec2 info is parsed
    #file_name: the name of the file you are creating and will get uploaded
    server_name = server.private_dns_name
    file_name = "remote_dependencies.rb"
    file_dir = "#{CAPISTRANO_UPLOAD_DIR}/#{server_name}"
    conf_file_name = "#{file_dir}/#{file_name}"

    begin
      File.delete(conf_file_name) if File.exists?(conf_file_name)
      Dir.mkdir(file_dir) unless File.exists?(file_dir)
      conf_file = File.new(conf_file_name, "w")
      conf_file.puts "#intializer remote dependencies file for app server #{server_name} (#{Time.now})\n\n"
      #IDManager
      conf_file.puts "#IDMANAGER"
      #conf_file.puts "ACCESS_MANAGER_URL = \"https://idmanager.ie.intuit.com/IDManager/services/AccessManagerSOAP\""
      #conf_file.puts "ACCOUNT_MANAGER_URL = \"https://idmanager.ie.intuit.com/IDManager/services/AccountManagerSOAP\""
      #conf_file.puts "TICKET_SERVER_URL = \".ticket.qbn.ie.intuit.com\"\n\n"
      conf_file.puts "AUTH_ENV = \".ptc\""
      conf_file.puts "QBN_ENV=\".ptcfe\""
      conf_file.puts "ACCESS_MANAGER_URL = \"https://idmanager.ie.intuit.com/IDManager/services/AccessManagerSOAP\""
      conf_file.puts "ACCOUNT_MANAGER_URL = \"https://idmanager.ie.intuit.com/IDManager/services/AccountManagerSOAP\""
      conf_file.puts "ACCOUNT_MANAGER_URN = \"http://spc.intuit.com/idmanager/account/\""
      conf_file.puts "ACCESS_MANAGER_URN  = \"http://spc.intuit.com/idmanager/access/\""
      conf_file.puts "TICKET_SERVER_URL = \".ticket.qbn.ie.intuit.com\"\n\n"
      conf_file.puts "FORGOT_URL = \"https://ttpmtqa.turbotax.intuit.com/commerce/account/secure/community_landing_page.jsp\""
      #FORGOT_USERID_LINK   = "https://ttpmtqa.turbotax.intuit.com/commerce/account/secure/forgot_login.jsp"
      #FORGOT_PASSWORD_LINK = "https://ttpmtqa.turbotax.intuit.com/commerce/account/secure/forgot_password.jsp"
      conf_file.puts "SIGNIN_HELP_LINK = \"https://ttpmtqa.turbotax.intuit.com/commerce/common/fragments/popup/esd/popup.jsp?content=signinhelpi\""
      conf_file.puts "OTHERSITE_LIST_LINK  =\"https://ttpmtqa.turbotax.intuit.com/commerce/common/fragments/popup/esd/popup.jsp?content=sitesusingaccount\""
      conf_file.puts "\n"
      #MEMCACHE
      conf_file.puts "#Memcache\n\n"
      conf_file.puts "MEMCACHED_ADDR = [#{cache_list}]"
      conf_file.puts "\n"
      #SEARCH
      conf_file.puts "#Search Info \n\n"
      conf_file.puts "SOLR_PATH = \"\#{RAILS_ROOT}/search/jetty\" unless defined? SOLR_PATH"
      conf_file.puts "SOLR_PORT = 8090 unless defined? SOLR_PORT"
      conf_file.puts "\n"
      conf_file.puts "PRIMARY_POST_SERVER = \"" + primary_post_server +"\""
      conf_file.puts "PRIMARY_TAG_SERVER  = \"" +  primary_tag_server + "\""
      conf_file.puts "PRIMARY_USER_SERVER = \"" + primary_user_server + "\""
      conf_file.puts "\n"
      conf_file.puts "POST_SERVER_CLUSTER = [" + post_server_cluster + "]"
      conf_file.puts "TAG_SERVER_CLUSTER = [" + tag_server_cluster + "]"
      conf_file.puts "USER_SERVER_CLUSTER = [" + user_server_cluster + "]"
      conf_file.puts "\n"
      #AWS
      conf_file.puts "#AWS\n\n"
      conf_file.puts "AWS_PROXY_HOST=\"proxy.ptc.intuit.com\""
      conf_file.puts "AWS_PROXY_PORT=80"
      conf_file.puts "\n"
      #MAIL
      conf_file.puts "#Mail\n\n"
      conf_file.puts "MAIL_ADDRESS=\"mail.intuit.com\""
      conf_file.puts "MAIL_PORT=25"
      conf_file.puts "MAIL_DOMAIN=\"www.turbotax.com\""
      conf_file.puts "TTO_LINK = \"https://ttolabqa13.turbotaxonline.intuit.com\""
      conf_file.puts "IDO_LINK = \"http://idoqaws.intuit.com\""
      conf_file.puts "TTLC_LINK = \"https://ciaperfws1.intuit.com/app/full_page\""
      conf_file.close
      puts `cat #{conf_file_name}`
    rescue => ex
      puts "Exception writing file: #{ex.inspect}"
    end
  end
  upload_app_conf(ecc, instances)
  cap "control:stop_unicorn", "amazon-perf"
  cap "control:start_unicorn", "amazon-perf"
  cap "control:stop_search", "amazon-perf"
  cap "control:start_search", "amazon-perf" 
end

