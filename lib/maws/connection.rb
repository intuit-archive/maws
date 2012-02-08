require 'right_aws'
require 'maws/mash'
require 'maws/description'
require 'maws/logger'

class Connection
  attr_reader :ec2, :rds, :elb

  def initialize(config)
    @config = config

    @access_key_id = @config.aws_key.key_id
    @secret_key = @config.aws_key.secret_key

    @params = {:region => @config.region, :logger => $right_aws_logger}
  end

  def connect(services)
    # The right_aws gem parses the EC2_URL environment variable if it is set. The EC2 CLI tools also use that variable
    # but expect the hostname to be region-specific (e.g., us-east-1.ec2.amazonaws.com) instead of generic
    # (e.g., ec2.amazonaws.com). To avoid conflicts, unset the variable here and use the right_aws default value.
    ENV["EC2_URL"] = nil

    # always connect to ec2
    @ec2 = RightAws::Ec2.new(@access_key_id, @secret_key, @params.dup)

    if services.include?(:rds)
      @rds = RightAws::RdsInterface.new(@access_key_id, @secret_key, @params.dup)
    end

    if services.include?(:elb)
      @elb = RightAws::ElbInterface.new(@access_key_id, @secret_key, @params.dup)
    end
  end

  def available_zones
    ec2.describe_availability_zones.
        find_all{ |zone_description| zone_description[:zone_state] == "available"}.
        map { |zone_description| zone_description[:zone_name][/\w$/]}
  end

  def image_id_for_image_name(image_name)
    return if image_name.nil? || image_name.empty?
    images = @ec2.describe_images(:filters => { 'tag:Name' => image_name})
    if images.empty?
      error "No AMI with name '#{image_name}'"
    elsif images.count > 1
      error "Ambigous AMI name: '#{image_name}'. Several AMIs match it #{images.collect{|i| i[:aws_id]}.join(', ')}"
    else
      images.first[:aws_id]
    end
  end

  def descriptions(services = nil)
    services ||= :all
    descriptions = []

    descriptions += ec2_descriptions if services == :all or services.include?(:ec2)
    descriptions += rds_descriptions if services == :all or services.include?(:rds)
    descriptions += elb_descriptions if services == :all or services.include?(:elb)

    descriptions
  end

  def ec2_descriptions
    filter_current_profile_prefix(filter_terminated_ec2_descriptions(all_ec2_descriptions))
  end

  def ebs_descriptions
    filter_current_profile_prefix(all_ebs_descriptions)
  end

  def rds_descriptions
    return [] unless rds

    filter_current_profile_prefix(all_rds_descriptions)
  end

  def elb_descriptions
    return [] unless elb

    filter_current_profile_prefix(all_elb_descriptions)
  end


  private

  def all_ec2_descriptions
    # convert aws description to Description
    ec2.describe_instances.map {|description|
      description[:service] = :ec2
      Description.create(description)
    }
  end

  def all_ebs_descriptions
    ec2.describe_volumes.map { |description|
      description[:service] = :ebs
      Description.create(description)
    }
  end

  def all_rds_descriptions
    rds.describe_db_instances.map { |description|
      description[:service] = :rds
      Description.create(description)
    }
  end

  def all_elb_descriptions
    elb.describe_load_balancers.map { |description|
      description[:service] = :elb
      Description.create(description)
    }
  end

  def filter_terminated_ec2_descriptions(descriptions)
    # filter out terminated when same name exists as a living one and terminated
    by_name = descriptions.group_by { |d| d.name }

    # if there is one than more for the same name: delete terminated descriptions, take the last one (trust AWS sorting)
    by_name.map {|name, descriptions|
      if descriptions.count > 1
        if descriptions.count {|d| d.status == "terminated"} != descriptions.count
          # don't delete all of them if all are terminated
          descriptions.delete_if {|d| d.status == "terminated"}
        end
        descriptions.replace([descriptions.last]).compact!
      end
    }

    by_name.values.flatten
  end

  def filter_current_profile_prefix(descriptions)
    descriptions.delete_if {|d| d.profile != @config.profile.name || d.prefix != @config.prefix}
  end

end