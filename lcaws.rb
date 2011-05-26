require 'lib/lcec2'

###############
# Script Start
###############
ecc = LcAws.new
instances = ecc.get_instances
instances.each_with_index do |i, index|
  puts "**** INSTANCE #{index} ****"
  puts i.to_s
  puts "***********************"
end

puts "WEB PROXY CONFIG"
ecc.print_proxy_members(instances)

puts "SSH commands (apps)"
LcAws.print_ssh_commands(ecc.get_app_instances(instances))

puts "SSH commands (loadgen)"
LcAws.print_ssh_commands(ecc.get_loadgen_instances(instances))

#puts "Stopping all app servers..."
#ecc.stop_app_servers
#puts "Done."

#puts "Stopping all loadgen servers..."
#ecc.stop_loadgen_servers
#puts "Done."
