#!/usr/local/bin/ruby

require './lib/lcec2'


ecc = LcAws.new

# add 3 web, 12 app to us-east1-b
#ecc.add_web_instances(3, "us-east-1b", ["web01", "web02","web03"])
#ecc.add_app_instances(18, "us-east-1b", ["app001","app002","app003","app004","app005","app006","app007","app008","app009","app010","app011","app012","app013","app014","app015","app016","app017","app018"])
ecc.add_loadgen_instances(3, "us-east-1b", ["loadgen01","loadgen02","loadgen03"])

# add 2 web, 12 app to us-east1-c
#ecc.add_web_instances(3, "us-east-1c", ["web04", "web05","web06"])
#ecc.add_app_instances(18, "us-east-1c", ["app019","app020", "app021", "app022", "app023", "app024","app025","app026","app027","app028","app029","app030","app031","app032","app033","app034","app035","app036"])
ecc.add_loadgen_instances(3, "us-east-1c", ["loadgen04","loadgen05","loadgen06"])


sleep 10

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
