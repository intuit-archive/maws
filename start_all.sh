ruby lcaws.rb start_apps
ruby lcaws.rb start_webs
ruby lcaws.rb start_services
ruby lcaws.rb start_searches

ruby lcaws.rb start_loadgens
ruby lcaws.rb validate_servers
ruby lcaws.rb create_envfile
ruby lcaws.rb update_database_configs
ruby lcaws.rb update_app_configs
ruby lcaws.rb update_web_configs

echo "*** now update loadgens ***"
ruby lcaws.rb show_webs