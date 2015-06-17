!!! This project has been deprecated. We recommend you fork it or look for an alternative solution. !!!

How do I install it?
====================

    sudo gem install maws

What is it for?
===============

MAWS is a tool for provisioning and managing complex deployments of AWS EC2, RDS and ELB instances. It's similar to Chef, but much simpler and for Amazon Web Services.

MAWS does not install services on instances. It uses pre-build AMIs that have different services ready. MAWS uses pre-made AMIs to provision any number of virtual instances. It then connects these instances to each other so they work together as a system.

MAWS aims to make deploying a multi-instance AWS infrastructure similar to deploying code or to deploying a system of services on a single box. "MAWS" doesn't stand for anything.


How do you use it?
=================

To use MAWS you need to install the maws Ruby gem, then create some config files and then run the `maws` command. It will look for and load the 'maws.yml' file in your working directory. See `examples` folder how to create MAWS configurations.

Your configs will specify what types of instances you have, how many of each type you would like and how they should be configured so they can see each other.

MAWS is a collection of commands that modify AWS instances. You need to specify the command to run and what instances to apply the command to. The tool will figure out the rest.

**MAWS has built in documentation. Use -h option to see available commands and how to use them.**

You run MAWS like this:

    maws profile-name command-name -s "...instance specification..." [other options]

See below for explanations of profile-name, command-name and 'instance specification'

Some definitions
================

Instance Name
-------------

The AWS account that MAWS uses can have any number of instances running. MAWS only sees some of them. They have to match MAWS style of naming. Maws instance names always look like this:

    [prefix.]profile-role-index[zone]

For example, with profile 'foo-test', role 'searchbox' and 3 search boxes in zone a, MAWS will expect to see these names:

    foo-test-searchbox-1a
    foo-test-searchbox-2a
    foo-test-searchbox-3a


Same name format is used for EC2, RDS and ELB services. Zone suffix is optional since some things might not be bound to a zone (for example, multi-zone RDS).

Profile Name
------------

The name of the application or environment MAWS should work on. MAWS needs this so that a single AWS account can be shared by many applications/environments.

Profile name is the first parameter to `maws` command. Profile name is used to select the _Profile Config_ (see below) MAWS should use.

If your system is called "foo" you might have profiles like: foo-prod, foo-test, foo-perf.

Role
----

Each instance has a role. The role determines what _Service_ (EC2, RDS, ELB) is used, what AMI is used if it's EC2.

The role of an instance determined how it will be configured to work with other instances.

Role names are like: app, web, cache, search, service, queue, masterdb, webloadbalancer, etc.


Service
-------

MAWS supports EC2, RDS and ELB services. Some commands also operate on EBS volumes. Each role must have a its service set.


Scope
-----

Scope can be either "zone" or "region." ELB and Multi-AZ RDS always have the scope set to "region." EC2 instances (and single zone RDS) always reside in a particular availability zone, but are able to have a "logical" zone that is blank (logically they belong to the region). If they have scope of "region" their _name_ does not contain the zone letter. For example, a control box instance does not need to exist in more than one zone so it would be scoped to "region", while an app server would likely be scoped to zone. We might end up with a list of instances that looks like this (assuming 1 of each instance in zones a and b):

    foo-app-1a
    foo-app-1b
    foo-control-1


Role Config
-----------

Located at roles/roles-set-name.yml. For application Foo this would be: roles/foo.yml. The role configs in foo.yml will be reused by multiple profiles (for example: foo-test, foo-prod, foo-perf).

This YAML file contains a hash. Each key is a name of a role, each value is a role definition. For example:

    masterdb:
        service: rds
        instance_class: 'db.m1.small'
        allocated_storage: 6
        master_username: 'dbuser'
        master_password: 'dbpass'
        db_name:
        parameter_group: 'foo-db'
    app:
        service: ec2
        image_name: 'foo-app-ami-name'
        instance_type: 't1.micro'
        security_groups:
            - default
        user_data: 'FOOAPPDATA'

Besides defining roles, role config file has several keys that apply to all roles. For example 'settings' key for global settings and 'aliases' key to store YAML aliases.


Profile Config
--------------

Located at roles/profile-name.yml. For example, test environment for application Foo would be stored at profiles/foo-test.yml.

Profile config has the format as roles config: a key for each role name and a value for the definition. MAWS will merge profile and role configs into a single definition.

With above role config for 'app' and profile config 'profiles/foo-test.yml' for 'app':

    app:
        count: 5
        security_groups:
            - test

The final merge config for role 'app' MAWS will use will be:

    app:
        count: 5
        service: ec2
        image_name: 'foo-app-ami-name'
        instance_type: 't1.micro'
        security_groups:
            - default
            - test
        user_data: 'FOOAPPDATA'


Profile config also needs to specify what roles config will be used and optionally the name of the security rules file (see below)

    roles: foo
    security_rules: foosec

`rule: foo` bit will make MAWS load and merge roles/foo.yml when profile foo-test is specified on the command line.


Instance Specification
----------------------

To use MAWS commands you have to specify what instances to operate on. The specification is limited to the selected profile name and the role names specified in the configs. Beyond these constrains any number of instances can be specified on the command line with -s option, like this:

    maws profile-name command-name -s "...instance specification..." [other options]

Instance specification is a string that describes what instances to operate on. These do not have to be instances that already exist. These can be instances that we want to exist.

Assuming profile and roles configs define the following roles: 'web' and 'app' each having a count of 5 and scoped to zones, the following specification would work:

* "a app web b c " -- selects all 5 of each web and app in zones 'a', 'b' and 'c' (order doesn't matter)
* "app" -- selects all 5 of app in all zones
* "b web-4" -- select 4th 'web' in zone b
* "app-3-5 c" -- selects 'app' instances 3, 4 and 5 in zone c only
* "web-1-10" -- select 'web' instances 1-10 in all zones
* "" -- select all 5 of 'app' and 'web' on all zones.
* "a app-*" -- select all apps in zone a that start at index 1 and end at the largest index for an alive, running 'app' instance on zone 'a' in AWS. If there are no alive 'app' instances on AWS, use 5 (count from profile) for highest index for 'app'. For example, if zone a is running `foo-test-app-2a` and `foo-test-app-7a` this specification will select 'app' 1-7 on zone a.
* "*" - select all 'app' and all 'web' in all zones starting at index 1 and ending with highest alive index or 5 (whichever is higher)


Prefix
------

Instance names can have a prefix. The default prefix is "" (blank), but any prefix can be specified with -p option.

Specification -s "a b app-2" (in profile foo-test) would select `foo-test-app-2a` and `foo-test-app-2b`

With prefix "backup": -s "a b app-2" -p "backup" (in profile foo-test) would select `backup.foo-test-app-2a` and `backup.foo-test-app-2b`

Prefixes can be used for deployment backups and other tricks. `set-prefix` command is used to add and remove prefixes.


Role Configurations/Templates
-----------------------------

MAWS needs to configure instances it creates to work together as a single system. It does this by generating config files from templates and uploading them to instances over SSH. For example, to configure Apache on 'web' instances to proxy to your application code on 'app' instances MAWS needs to generate and upload httpd.conf to web instances.

This is how MAWS knows that 'web' instances need to receive a 'httpd-vhosts.conf' file that connects them to 'app' instances.

    web:
        configurations:
            -
                name: vhosts
                template: 'httpd-vhosts.conf'
                location: '/usr/local/apache2/conf/httpd-vhosts.conf'
                copy_as_user: 'root'
                template_params:
                    balancer: self
                    balancer_members:
                        select_many:
                            role: app
                            from: zone
                            chunk_size: 2

MAWS will look for templates/httpd-vhosts.conf.erb, it will process the template and insert 'app' instance host information into the template. It will upload the generated httpd-vhosts.conf file to /usr/local/apache2/conf/httpd-vhosts.conf on each 'web' instance.

Here's what the template httpd-vhosts.conf.erb looks like:

    # The app servers below will be get requests from this web server <%= balancer.name %
    # AKA <%= balancer.aws_id %    or <%= balancer.ip_address %    or <%= balancer.private_ip_address %
    <Proxy balancer://app_cluster
    <% balancer_members.each do |member| %
     # <%= member.name %
      BalancerMember http://<%= member.private_ip_address %    :8080
    <% end %
    </Proxy>


Besides uploading templated configuration, MAWS can also run remote configuration commands via SSH on remote instances. The available commands are specified like this:

    app:
       configurations:
          -
            name: killunicorns
            command: 'su - foouser -c "cd /foo/site; if [ -e tmp/pids/unicorn.pid ]; then <tmp/pids/unicorn.pid xargs kill; fi"'


Apply these configurations using `configure` command. For example, to kill unicorns on all 'app' in zone b:

    maws foo-test configure -s "b app" -c killunicorns

Template Parameters
-------------------

In the above template configuration `balancer` and `balancer_members` are provided to the template using the `template_params` settings in the roles configuration file.

Each key for `template_params` is of param. The value for the key selects what instance(s) to assign to that name. In that example `balancer: self` will assign the current 'web' instance being configured.

`balancer_member` is a `select_many` parameter. `select_many` will pick a number of some alive, running instances matching the role. `chunk_size` decides how many 'app' instances will be selected. Without `chunk_size`, MAWS will select all 'app' instances. With `chunk_size` each 'web' instance will get 2 'app' instances. These 'app' instances will be assigned in round robin way (assuming 2 'web' and 3 'app'): web1 will get app1 and app2; web2 will get app3 and app1.

Other options are:
* `select_one: app` will pick one 'app' for each 'web' in round-robin order.
* `select_many: app` will pick all 'app' for each web.

`select_one` returns a single instance, while `select_many` returns an array.


Security Rules
--------------

Profile and role configs can specify `security_group` for any role. In addition to that, you can optionally use a security rules file to create AWS security groups on dynamically for your profiles using `set-security-rules` command. These dynamic security groups will be automatically assigned when MAWS creates new instances.

If your profile config contains `security_rules: foosec` MAWS will load and use security_rules/foosec.yml.

This is an example of this security rules:

    rds_default:
        -
            cidr: '0.0.0.0/0'
        -
            role: app

    app:
        -
            role: web
            port: 8080
            protocol: tcp
        -
            cidr: ['1.1.1.1/1', '2.2.2.2/2']
            port_from: 10000
            port_to: 10100
            protocol: udp

    web:
        -
            group: 'amazon-elb/sg-843f59ed'
            port: 80
            protocol: tcp


Incoming firewall rules can be specified either as a AWS security group, a CIDR or a MAWS role. `rds_default` will be assigned to all RDS instances, while `ec2_default` will be assigned to all EC2 instances.

The above configuration will generate and create/update the following security groups (when MAWS `set-security-groups` is run for profile foo-test):

* rds_default
* foo-test-app
* foo-test-web






