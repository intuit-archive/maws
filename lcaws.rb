require 'lib/lcec2'


def list_instances(instances)
  instances.each_with_index do |i, index|
    puts "**** INSTANCE #{index} ****"
    puts i.to_s
    puts "***********************"
  end
end

def print_web_proxy_config(ecc,instances)
  puts "WEB PROXY CONFIG"
  ecc.print_proxy_members(instances)
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
  puts "Stopping all loadgen servers..."
  ecc.stop_loadgen_servers
  puts "Done."
end

def print_usage
  puts "USAGE: ruby lcaws.rb [list][web-proxy][ssh-commands][stop-apps][start-apps]\n"+
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
    start_apps(ecc) if arg == "start_apps"
  end
end