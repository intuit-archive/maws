require 'lib/command'

class SetSecurityGroups < Command
  def run!
    rules = @profile.security_rules
    if rules.empty?
      info "No security rules to create security groups from"
      return
    end

    @security_group_definitions = {}
    rules.keys.map {|rules_set_name|
      security_group_name = "#{@profile.name}-#{rules_set_name}"
      service = if rules_set_name == 'ec2_default'
        :ec2
      elsif rules_set_name == 'rds_default'
        :rds
      else
        @profile.service_for_role_name(rules_set_name)
      end

      @security_group_definitions[security_group_name] = {
              :role => rules_set_name,
              :rules => rules[rules_set_name],
              :service => service}
    }

    update_definitions_with_descriptions(@security_group_definitions)

    @security_group_definitions.each { |name, definition|
      create_security_group(name, definition) unless definition[:description]
    }

    update_definitions_with_descriptions(@security_group_definitions)
    begin
      update_definitions_rules_with_real_ids(@security_group_definitions)
    rescue BadSecurityRule => err
      info "Bad security rule: #{err.message}"
      info "No AWS security rules will be updated."
      return
    end

    @security_group_definitions.each { |name, definition|
      info "#{definition[:service]} security group #{name}"

      clear_out_security_group(name, definition)

      # rds takes a while to propagate. this code handles errors with retries, but this sleep keeps the noise down
      if definition[:service] == :rds
        info "...waiting for revoke to take effect..."
        sleep 20
      end

      set_security_group(name, definition)

      info "done\n\n"
    }
  end

  # sets :description, :group_id, :group_name and :owner_id for each definition
  def update_definitions_with_descriptions(security_group_definitions)
    ec2_sg_descriptions = @connection.ec2.describe_security_groups
    rds_sg_descriptions = @connection.rds.describe_db_security_groups

    # attach existing descriptions (if they exist) to sec group definition
    security_group_definitions.each {|name, definition|
      if definition[:service] == :ec2
        definition[:description] = ec2_sg_descriptions.find {|description| description[:aws_group_name] == name }
        if definition[:description]
          definition[:group_id] = definition[:description][:group_id]
          definition[:group_name] = definition[:description][:aws_group_name]
          definition[:owner_id] = definition[:description][:aws_owner]
        end
      elsif definition[:service] == :rds
        definition[:description] = rds_sg_descriptions.find {|description| description[:name] == name }
        if definition[:description]
          definition[:group_id] = definition[:description][:name]
          definition[:group_name] = definition[:description][:name]
          definition[:owner_id] = definition[:description][:owner_id]
        end
      end
    }
  end



  def create_security_group(name, definition)
    info "CREATING #{name}"

    if definition[:service] == :ec2
      @connection.ec2.create_security_group(name, name) # description same as name
    elsif definition[:service] == :rds
      @connection.rds.create_db_security_group(name, name)
    end
  end

  def clear_out_security_group(name, definition)
    info "    clearing out #{name}"
    description =  definition[:description]
    return unless description && !description.empty?


    if definition[:service] == :ec2
      clear_out_ec2_security_group(name, description)
    elsif definition[:service] == :rds
      clear_out_rds_security_group(name, description)
    end
  end

  def set_security_group(name, definition)
    info "    adding security rules to #{name}"
    service = definition[:service]

    definition[:rules].each { |rule|
      rule.port ||= 0
      rule.port_from ||= (rule.port)
      rule.port_to ||= (rule.port)

      protocol_description = service == :ec2 ? "#{rule.protocol}:#{rule.port_from}-#{rule.port_to}" : ""

      if rule.group
        info "        allow from #{rule.owner_id}/#{rule.group_id} (#{rule.group}) #{protocol_description}"
        if service == :ec2
          authorize_ec2_security_group_rule(definition[:group_id], rule.port_from, rule.port_to, rule.protocol,
                                            :groups => {rule.owner_id => rule.group_id})
        else
          safe_authorize_rds_security_group_rule(definition[:group_id],
                                            :ec2_security_group_owner => rule.owner_id,
                                            :ec2_security_group_name => rule.group_name)
        end
      elsif rule.role
        info "        allow from #{rule.owner_id}/#{rule.group_id} (role '#{rule.role}') #{protocol_description}"
        if service == :ec2
          authorize_ec2_security_group_rule(definition[:group_id], rule.port_from, rule.port_to, rule.protocol,
                                            :groups => {rule.owner_id => rule.group_id})
        else
          safe_authorize_rds_security_group_rule(definition[:group_id],
                                            :ec2_security_group_owner => rule.owner_id,
                                            :ec2_security_group_name => rule.group_id)
        end
      elsif rule.cidr
        info "        allow from #{rule.cidr.inspect} #{protocol_description}"
        if service == :ec2
          authorize_ec2_security_group_rule(definition[:group_id], rule.port_from, rule.port_to, rule.protocol,
                                            :cidr_ips => [rule.cidr].flatten)
        else
          [rule.cidr].flatten.each { |cidr|
            safe_authorize_rds_security_group_rule(definition[:group_id], :cidrip => cidr)
          }
        end
      end
    }
  end

  ### EC2 ###

  def clear_out_ec2_security_group(name, description)
    description[:aws_perms].each { |permission|
      group_id = description[:group_id]

      revoke_params = if permission[:group_id]
        # this is a group rule
        {:groups => {permission[:owner] => permission[:group_id]}}
      else
        {:cidr_ip => permission[:cidr_ips]}
      end

      revoke_params[:protocol] = permission[:protocol]
      revoke_params[:from_port] = permission[:from_port]
      revoke_params[:to_port] = permission[:to_port]

      info "        revoking #{revoke_params.inspect}"
      @connection.ec2.modify_security_group(:revoke, :ingress,
        group_id, revoke_params);
    }
  end

  def authorize_ec2_security_group_rule(group_id, from_port, to_port, protocol, rule)
    params = {:from_port  => from_port,
              :to_port    => to_port,
              :protocol   => protocol}.merge(rule)
    @connection.ec2.modify_security_group(:authorize, :ingress, group_id, params)
  end



  ### RDS ###

  def clear_out_rds_security_group(name, description)
    description[:ec2_security_groups].each {|group_permission|
      info "        revoking from #{group_permission[:owner_id]}/#{group_permission[:name]}"
      safe_revoke_rds_security_group(name,
                                       :ec2_security_group_owner => group_permission[:owner_id],
                                       :ec2_security_group_name  => group_permission[:name])
    }

    description[:ip_ranges].each {|ip_permission|
      info "        revoking from #{ip_permission[:cidrip].inspect}"
      safe_revoke_rds_security_group(name, :cidrip => ip_permission[:cidrip])
    }
  end


  def update_definitions_rules_with_real_ids(definitions)
    definitions.each { |name, definition|
      definition[:rules].each { |rule|
        next if rule.cidr

        owner_id, group_id = if rule.role
          owner_id, group_id = resolve_owner_and_group_id_for_role_definition(rule.role)
        elsif rule.group
          owner_id, group_id = resolve_owner_and_group_id_for_group_definition(rule.group)
        end

        unless owner_id && group_id
          raise BadSecurityRule.new("Can't resolve security group id and owner for rule #{rule.inspect}}")
        else
          rule.owner_id = owner_id
          rule.group_id = group_id
        end
      }
    }

  end


  def resolve_owner_and_group_id_for_role_definition(role_name)
    definition = @security_group_definitions.values.find {|definition| definition[:role] == role_name}
    if definition
      [definition[:owner_id], definition[:group_id]]
    else
      security_group_name = "#{@profile.name}-#{role_name}"
      raise BadSecurityRule.new("Can't find security group '#{security_group_name}' for role '#{role_name}'")
    end
  end

  def resolve_owner_and_group_id_for_group_definition(group_definition)
    # 'owner_id/group_name' => ['owner_id', 'group_name'] OR 'group_name' => ['group_name']
    owner_id_and_group = group_definition.split('/')

    group = owner_id_and_group.pop
    owner_id = owner_id_and_group.pop

    group_id = if group =~ /sg-/
      group
    else
      # look up name
      definition = @security_group_definitions.values.find {|definition| definition[:group_name] == group}

      definition[:group_id] if definition
    end

    raise BadSecurityRule.new("Can't find group id (sg-...) for group name #{group}") unless group_id

    # use this account for owner id
    owner_id = @security_group_definitions.values.first[:owner_id] unless owner_id

    [owner_id, group_id]
  end


  def safe_revoke_rds_security_group(name, params)
    rds_logger = @connection.rds.logger
    @connection.rds.logger = NullLogger.new

    tries = 4

    loop do
      if tries <= 0
        info "!!!!!! FAILED TO REVOKE: #{name} #{params.inspect} !!!!!!"
        return
      end

      begin
        @connection.rds.revoke_db_security_group_ingress(name, params)
        info "            (succesfully revoked)"
        return
      rescue Exception => e
        if e.message =~ /AuthorizationNotFound/
          info "            (not authorized. nothing to do here)"
          return

        elsif e.message =~ /InvalidDBSecurityGroupState: Cannot revoke an authorization that is in the revoking state/
          info "            (already revoking - will be revoked shortly)"
          sleep 10
          tries -= 1

        elsif e.message =~ /InvalidDBSecurityGroupState: Cannot revoke an authorization that is in the authorizing state/
          info "            (not yet finished authorizing. waiting and retrying...)"
          sleep 10
          tries -= 1

        else
          sleep 1
          tries -= 1
        end
      end
    end
  ensure
    @connection.rds.logger = rds_logger
  end


  def safe_authorize_rds_security_group_rule(name, params)
    rds_logger = @connection.rds.logger
    @connection.rds.logger = NullLogger.new

    tries = 4

    loop do
      if tries <= 0
        info "!!!!!! FAILED TO AUTHORIZE: #{name} #{params.inspect} !!!!!!"
        return
      end

      begin
        @connection.rds.authorize_db_security_group_ingress(name, params)
        info "            (succesfully authorized)"
        return
      rescue Exception => e
        if e.message =~ /AuthorizationAlreadyExists/
          info "            (authorization already exists. probably means it is still being revoked. retrying...)"
          sleep 10
          tries -= 1

        elsif e.message =~ /InvalidDBSecurityGroupState: Cannot authorize an authorization that is in the revoking state/
          info "            (currently revoking - will be revoked shortly. will retry authorizing then)"
          sleep 10
          tries -= 1

        elsif e.message =~ /InvalidDBSecurityGroupState: Cannot authorize an authorization that is in the authorizing state/
          info "            (already authorizing. waiting and retrying to confirm...)"
          sleep 10
          tries -= 1

        else
          sleep 1
          tries -= 1
        end
      end
    end
  ensure
    @connection.rds.logger = rds_logger
  end


##### DESCRIPTIONS ######

### EC2 ###

# ec2.describe_security_groups #=>
#       [{:aws_perms=>
#         [{:owner=>"375390957666",
#           :direction=>:ingress,
#           :protocol=>"tcp",
#           :group_id=>"sg-d7e9d9be",
#           :from_port=>"22",
#           :group_name=>"bps-e2e-queue",
#           :to_port=>"22"},

#          {:cidr_ips=>"208.240.243.170/32",
#            :direction=>:ingress,
#            :protocol=>"tcp",
#            :from_port=>"22",
#            :to_port=>"22"}],

#          {:owner=>"375390957666",
#           :direction=>:ingress,
#           :protocol=>"icmp",
#           :group_id=>"sg-9f5d5cf6",
#           :from_port=>"15",
#           :group_name=>"bps-e2e-service",
#           :to_port=>"-1"}],

#        :aws_owner=>"375390957666",
#        :aws_description=>"something here",
#        :group_id=>"sg-30fd1b58",
#        :aws_group_name=>"test2"}]

# @connection.ec2.modify_security_group(:grant, :ingress,
#     'sg-30fd1b58', {:protocol => 'tcp', :port => 22, :cidr_ip => '127.0.0.2/32'})
#
# @connection.ec2.modify_security_group(:revoke, :ingress,
#     'sg-30fd1b58', {:protocol => :tcp, :port => 22, :groups => {'375390957666' => 'sg-d7e9d9be'} });



### RDS ###

# rds.describe_db_security_groups #=>
#   [{:owner_id=>"375390957666",
#     :description=>"Default",
#     :ec2_security_groups=>[],
#     :ip_ranges=>[],
#     :name=>"Default"},
#    {:owner_id=>"375390957666",
#     :description=>"kd",
#     :ec2_security_groups=>[],
#     :ip_ranges=>[],
#     :name=>"kd2"},
#    {:owner_id=>"375390957666",
#     :description=>"kd",
#     :ec2_security_groups=>
#      [{:status=>"Authorized", :owner_id=>"375390957666", :name=>"default"},
#       {:status=>"Authorized", :owner_id=>"375390957666", :name=>"default1"},
#       {:status=>"Authorized", :owner_id=>"375390957666", :name=>"default"},
#       {:status=>"Authorized", :owner_id=>"375390957666", :name=>"default"},
#       {:status=>"Authorized", :owner_id=>"375390957666", :name=>"default1"},
#       {:status=>"Authorized", :owner_id=>"375390957666", :name=>"default22"}],
#     :ip_ranges=>
#      [{:status=>"Authorized", :cidrip=>"127.0.0.1/8"},
#       {:status=>"Authorized", :cidrip=>"128.0.0.1/8"},
#       {:status=>"Authorized", :cidrip=>"129.0.0.1/8"},
#       {:status=>"Authorized", :cidrip=>"130.0.0.1/8"},
#       {:status=>"Authorized", :cidrip=>"131.0.0.1/8"}],
#     :name=>"kd3"}]

# rds.revoke_db_security_group_ingress('kd2', :ec2_security_group_owner => '375390957666',
#                                            :ec2_security_group_name => 'default')
#
# rds.revoke_db_security_group_ingress('kd2', :cidrip=>"127.0.0.1/8")
#
# rds.authorize_db_security_group_ingress('kd3', :cidrip => '131.0.0.1/8')
end

class BadSecurityRule < Exception
end
