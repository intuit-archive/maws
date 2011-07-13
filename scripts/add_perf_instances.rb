#!/usr/local/bin/ruby

require './lib/lcec2'


ecc = LcAws.new

# add 2 web, 12 app to us-east1-b
ecc.add_web_instances(2, "us-east-1b", ["web01", "web02"])
ecc.add_app_instances(12, "us-east-1b", ["app001", "app002", "app003", "app004", "app005", "app006", "app007", "app008", "app009", "app010", "app011", "app012"])

# add 2 web, 12 app to us-east1-c
ecc.add_web_instances(2, "us-east-1c", ["web03", "web04"])
ecc.add_app_instances(12, "us-east-1c", ["app013", "app014", "app015", "app016", "app017", "app018", "app019", "app020", "app021", "app022", "app023", "app024"])

# add 10 loadgen instances in each zone
ecc.add_loadgen_instances(10, "us-east-1b", ["loadgen01","loadgen02","loadgen03","loadgen04","loadgen05","loadgen06","loadgen07","loadgen08","loadgen09","loadgen10",])
ecc.add_loadgen_instances(10, "us-east-1c", ["loadgen11","loadgen12","loadgen13","loadgen14","loadgen15","loadgen16","loadgen17","loadgen18","loadgen19","loadgen20",])

sleep 5

# ensure they were added

instances = ecc.get_instances
apps = ecc.get_app_instances(instances, "running")
webs = ecc.get_web_instances(instances, "running")
lgs = ecc.get_loadgen_instances(instances, "running")

apps.sort! {|a,b| a.name[3..-1].to_i <=> b.name[3..-1].to_i}
webs.sort! {|a,b| a.name[3..-1].to_i <=> b.name[3..-1].to_i}
lgs.sort! {|a,b| a.name[3..-1].to_i <=> b.name[3..-1].to_i}

puts "*** APPS ***"
apps.each do |app|
  puts "Found #{app.name}"
end

puts "*** WEBS ***"
webs.each do |web|
  puts "Found #{web.name}"
end

puts "*** LOADGENS ***"
lgs.each do |lg|
  puts "Found #{lg.name}"
end

#TODO: automate the remaining tasks...
puts "now create the envfile, web proxy configs, and database configs, then add the web servers to the load balancer and it's SHOW TIME!"
