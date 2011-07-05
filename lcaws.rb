require './lib/lcec2'

PEM_PATH = ENV["AWS_PEM_PATH"]


def list_instances(instances)
  instances.each_with_index do |i, index|
    puts "**** INSTANCE #{index} ****"
    puts i.to_s
    puts "***********************"
  end
end

def get_web_proxy_config(ecc, instances, apps_per_web=6)
  ws_num = 0
  app_count = 0
  webs = Array.new

  apps = ecc.get_app_instances(instances)
  
  # sort by the number appended to the name
  apps.sort! {|a,b| a.name[3..-1].to_i <=> b.name[3..-1].to_i}
  
  apps.each do |instance|
    if instance.running?
      webs[ws_num] = Array.new if webs[ws_num].nil?
      webs[ws_num] << "# #{instance.name} \n BalancerMember http://#{instance.private_dns_name}:8080"
      app_count += 1
    end
    if app_count >= apps_per_web
      # on to the next web server
      ws_num += 1
      app_count = 0
    end
  end
  return webs
end

def print_web_proxy_config(ecc,instances, apps_per_web=6)
  webs = get_web_proxy_config(ecc, instances, apps_per_web)
  # now print the elements of the webs arrays
  webs.each_with_index do |w,index|
    puts "#Web#{index+1}\n# Proxy Balancer: add app-server hosts here to include them in this web server's proxy balancer\n#\n<Proxy balancer://turbotax_cluster>\n"
    w.each do |line|
      puts " " + line
    end
    puts "</Proxy>"
  end
end

def print_database_configs(ecc, instances)
  dbs = ecc.get_rds_instances
  
end

def print_ssh_commands(ecc,instances)
  puts "SSH commands (apps)"
  LcAws.print_ssh_commands(ecc.get_app_instances(instances))

  puts "SSH commands (loadgen)"
  LcAws.print_ssh_commands(ecc.get_loadgen_instances(instances))
end

def stop_apps(ecc)
  puts "Stopping all app servers..."
  ecc.stop_app_servers
  puts "Done."
end

def start_apps(ecc)
  puts "Starting all app servers..."
  ecc.start_app_servers
  puts "Done."
end

def show_apps(ecc,instances)
  puts "Current App servers:"
  apps = ecc.get_app_instances(instances)
  apps.each do |app|
    puts app.name + " : " + app.state
  end
end

def open_app_terminals(ecc, instances)
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

def stop_loadgens(ecc)
  puts "Stopping all loadgen servers..."
  ecc.stop_loadgen_servers
  puts "Done."
end

def start_loadgens(ecc)
  puts "Starting all loadgens servers..."
  ecc.start_loadgen_servers
  puts "Done."
end

def show_loadgens(ecc,instances)
  puts "Current loadgens servers:"
  servers = ecc.get_loadgen_instances(instances)
  servers.each do |lg|
    puts lg.name + " : " + lg.state
  end
end

def show_dbs(ecc)
  puts "Current Database Instances:"
  dbs = ecc.get_rds_instances
  dbs.each do |db|
    puts db.to_s
    puts ' '
  end
end

def scp_loadgen_results(ecc, instances)
  servers = ecc.get_loadgen_instances(instances)
  servers.each do |lg|
    if lg.running?
      cmd =  "scp -i ~/mattinasi.pem root@#{lg.dns_name}:/home/loaduser/performance_result.log #{lg.name}.performance_result.log"
      puts "executing: #{cmd}"
      `#{cmd}`
    end
  end
end

def open_loadgen_terminals(ecc, instances)
  servers = ecc.get_loadgen_instances(instances)
  servers.each do |lg|
    if lg.running?
      cmd =  "ssh -i ~/mattinasi.pem root@#{lg.dns_name}"
      puts "opening terminal as: #{cmd}"
      `scripts/it #{cmd}`
    end
  end
end

def open_web_terminals(ecc, instances)
  servers = ecc.get_web_instances(instances)
  servers.each do |w|
    if w.running?
      cmd =  "ssh -i ~/mattinasi.pem root@#{w.dns_name}"
      puts "opening terminal as: #{cmd}"
      `scripts/it #{cmd}`
    end
  end
end

def print_usage
  puts "USAGE: ruby lcaws.rb [list][web-proxy][ssh-commands][stop-apps][start-apps][show-apps][open-apps][stop-loadgens][start-loadgens][show-loadgens][open-loadgens][open-webs][show-dbs][scp-loadgen-results]\n"+
       "  There should be at least one command. If more than one command is specified then commands are executed in order"
end

###############
# Script Start
###############
if ARGV.size < 1
  print_usage
else
  ecc = LcAws.new
  instances = ecc.get_instances

  ARGV.each do |arg|
    list_instances(instances) if arg == "list"
    print_web_proxy_config(ecc,instances) if arg == "web-proxy"
    print_ssh_commands(ecc,instances) if arg == "ssh-commands"
    stop_apps(ecc) if arg == "stop-apps"
    start_apps(ecc) if arg == "start-apps"
    show_apps(ecc,instances) if arg == "show-apps"
    open_app_terminals(ecc,instances) if arg == "open-apps"
    stop_loadgens(ecc) if arg == "stop-loadgens"
    start_loadgens(ecc) if arg == "start-loadgens"
    show_loadgens(ecc,instances) if arg == "show-loadgens"
    open_loadgen_terminals(ecc, instances) if arg == "open-loadgens"
    open_web_terminals(ecc, instances) if arg == "open-webs"
    scp_loadgen_results(ecc,instances) if arg == "scp-loadgen-results"
    show_dbs(ecc) if arg == "show-dbs"
  end
end