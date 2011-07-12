#!/usr/local/bin/ruby

require './lib/lcec2'


ecc = LcAws.new

# add 2 web, 12 app to us-east1-b
ecc.add_web_instances(2, "us-east-1b", ["web01", "web02"])
ecc.add_app_instances(12, "us-east-1b", ["app001", "app002", "app003", "app004", "app005", "app006", "app007", "app008", "app009", "app010", "app011", "app012"])

# add 2 web, 12 app to us-east1-c
ecc.add_web_instances(2, "us-east-1c", ["web03", "web04"])
ecc.add_app_instances(12, "us-east-1c", ["app013", "app014", "app015", "app016", "app017", "app018", "app019", "app020", "app021", "app022", "app023", "app024"])

# ensure they were added

instances = ecc.get_instances
apps = ecc.get_app_instances(instances, "running")
webs = ecc.get_web_instances(instances, "running")
apps.sort! {|a,b| a.name[3..-1].to_i <=> b.name[3..-1].to_i}
webs.sort! {|a,b| a.name[3..-1].to_i <=> b.name[3..-1].to_i}

apps.each do |app|
  puts "Found #{app.name}"
end

webs.each do |web|
  puts "Found #{web.name}"
end

puts "now create the web proxy configs and add the web servers to the load balancer..."
