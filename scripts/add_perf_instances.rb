#!/usr/local/bin/ruby

require './lib/lcec2'

ecc = LcAws.new

# add 2 web, 12 app, 1 service, search, queue and cache to us-east1-b
ecc.add_web_instances(2, "us-east-1b", ["web01", "web02"])
ecc.add_app_instances(12, "us-east-1b", ["app001","app002","app003","app004","app005","app006","app007","app008","app009","app010","app011","app012"])
ecc.add_service_instances(1, "us-east-1b", ["services01"])
ecc.add_search_instances(1, "us-east-1b", ["search01"])
ecc.add_cache_instances(1, "us-east-1b", ["cache01"])
ecc.add_queue_instances(1, "us-east-1b", ["queue01"])
ecc.add_loadgen_instances(2, "us-east-1b", ["loadgen01","loadgen02"])

# add 2 web, 12 app, 1 service, search, queue and cache to us-east1-c
ecc.add_web_instances(2, "us-east-1c", ["web03", "web04"])
ecc.add_app_instances(12, "us-east-1c", ["app013","app014","app015","app016","app017","app018","app019","app020", "app021", "app022", "app023", "app024"])
ecc.add_service_instances(1, "us-east-1c", ["services02"])
ecc.add_search_instances(1, "us-east-1c", ["search02"])
ecc.add_cache_instances(1, "us-east-1c", ["cache02"])
ecc.add_queue_instances(1, "us-east-1c", ["queue02"])
ecc.add_loadgen_instances(2, "us-east-1c", ["loadgen03","loadgen04"])

puts "waiting for AWS to catch-up "
5.times do
  puts "."
  sleep 5
end
puts "ok, now validating servers are running and accessible"

# check that they were added
system "ruby lcaws.rb validate_servers skip_private_ip"

instances = ecc.get_instances
apps = ecc.get_app_instances(instances, "running")
webs = ecc.get_web_instances(instances, "running")
services = ecc.get_instances_by_name("services", instances, "running")
searches = ecc.get_instances_by_name("search", instances, "running")
caches = ecc.get_instances_by_name("cache", instances, "running")
queues = ecc.get_instances_by_name("queue", instances, "running")
lgs = ecc.get_loadgen_instances(instances, "running")

apps.sort! {|a,b| a.name[3..-1].to_i <=> b.name[3..-1].to_i}
webs.sort! {|a,b| a.name[3..-1].to_i <=> b.name[3..-1].to_i}
services.sort! {|a,b| a.name[3..-1].to_i <=> b.name[3..-1].to_i}
searches.sort! {|a,b| a.name[3..-1].to_i <=> b.name[3..-1].to_i}
caches.sort! {|a,b| a.name[3..-1].to_i <=> b.name[3..-1].to_i}
queues.sort! {|a,b| a.name[3..-1].to_i <=> b.name[3..-1].to_i}
lgs.sort! {|a,b| a.name[3..-1].to_i <=> b.name[3..-1].to_i}


puts "*** APPS ***"
apps.each do |app|
  puts "Found #{app.name}"
end

puts "*** WEBS ***"
webs.each do |web|
  puts "Found #{web.name}"
end

puts "*** SERVICES ***"
services.each do |svc|
  puts "Found #{svc.name}"
end

puts "*** SEARCHES ***"
searches.each do |srch|
  puts "Found #{srch.name}"
end

puts "*** CACHES ***"
caches.each do |cache|
  puts "Found #{cache.name}"
end

puts "*** QUEUES ***"
queues.each do |q|
  puts "Found #{q.name}"
end

puts "*** LOADGENS ***"
lgs.each do |lg|
  puts "Found #{lg.name}"
end

#TODO: automate the remaining tasks...
puts "now create the envfile, web proxy configs, and database configs, then add the web servers to the load balancer and it's SHOW TIME!"
