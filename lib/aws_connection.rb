if `whoami`.chomp == "jgaigalas"
  puts "DEBUG: requiring local right_aws gem"
  require '/Users/jgaigalas/src/right_aws/lib/right_aws'
else
  require 'right_aws'
  require 'lib/logger'
end

class AwsConnection
  attr_accessor :silent

  def initialize(keyid, key, options)
    @access_key_id = keyid
    @secret_key = key
    @options = options

    @params = {:region => @options.region, :logger => $right_aws_logger}
    @silent = false
    info "ZONE: #{@options.availability_zone}\n\n"
  end

  def ec2
    @ec2 ||= RightAws::Ec2.new(@access_key_id, @secret_key, @params.dup)
  end

  def rds
    @rds ||= RightAws::RdsInterface.new(@access_key_id, @secret_key, @params.dup)
  end

  def elb
    @elb ||= RightAws::ElbInterface.new(@access_key_id, @secret_key, @params.dup)
  end

  def ec2_descriptions
    return @ec2_descriptions if @ec2_descriptions
    info "fetching all EC2 instances info from AWS..." unless @silent
    @ec2_descriptions = ec2.describe_instances
    info "...done (received #{@ec2_descriptions.count} EC2 descriptions from AWS)\n\n" unless @silent

    @ec2_descriptions
  end

  def rds_descriptions
    return @rds_descriptions if @rds_descriptions

    info "fetching all RDS instances info from AWS..." unless @silent
    @rds_descriptions = rds.describe_db_instances
    info "...done (received #{@rds_descriptions.count} RDS descriptions from AWS)\n\n" unless @silent

    @rds_descriptions
  end

  def elb_descriptions
    return @elb_descriptions if @elb_descriptions

    @elb_descriptions ||= elb.describe_load_balancers
  end

  def clear_cached_descriptions
    @rds_descriptions = nil
    @ec2_descriptions = nil
    @elb_descriptions = nil
  end

  def ec2_name_grouped_descriptions
    ec2_name_grouped_descriptions = {}
    ec2_descriptions.each do |d|
      name = d[:tags]["Name"] || d[:aws_instance_id]
      ec2_name_grouped_descriptions[name] = d
    end

    ec2_name_grouped_descriptions
  end

  def rds_name_grouped_descriptions
    rds_name_grouped_descriptions = {}
    rds_descriptions.each do |description|
      rds_name_grouped_descriptions[description[:aws_id]] = description
    end

    rds_name_grouped_descriptions
  end

  def description_for_name name
    ec2_name_grouped_descriptions[name] || rds_name_grouped_descriptions[name]
  end
end