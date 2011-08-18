# require 'right_aws'
require '/Users/jgaigalas/src/right_aws/lib/right_aws'
require 'lib/logger'

class AwsConnection
  def initialize(keyid, key, options)
    @access_key_id = keyid
    @secret_key = key
    @options = options

    @params = {:region => @options.region, :logger => $logger}
    info "ZONE: #{@options.availability_zone}\n\n"
  end

  def ec2
    @ec2 ||= RightAws::Ec2.new(@access_key_id, @secret_key, @params.dup)
  end

  def rds
    @rds ||= RightAws::RdsInterface.new(@access_key_id, @secret_key, @params.dup)
  end

  def ec2_descriptions
    return @ec2_descriptions if @ec2_descriptions
    info "Fetching all EC2 instances info from AWS..."
    @ec2_descriptions = ec2.describe_instances
    @ec2_descriptions.delete_if {|description| description[:aws_availability_zone] != @options.availability_zone}
    info "...done (received #{@ec2_descriptions.count} EC2 descriptions from AWS)"

    @ec2_descriptions
  end

  def rds_descriptions
    return @rds_descriptions if @rds_descriptions

    info "Fetching all RDS instances info from AWS..."
    @rds_descriptions = rds.describe_db_instances
    @rds_descriptions.delete_if do |description|
      (description[:availability_zone] != @options.availability_zone) && !description[:multi_az]
    end
    info "...done (received #{@rds_descriptions.count} RDS descriptions from AWS)\n\n\n"

    @rds_descriptions
  end


  def ec2_name_grouped_descriptions
    return @ec2_name_grouped_descriptions if @ec2_name_grouped_descriptions
    @ec2_name_grouped_descriptions = {}
    ec2_descriptions.each do |d|
      name = d[:tags]["Name"] || d[:aws_instance_id]
      @ec2_name_grouped_descriptions[name] = d
    end

    @ec2_name_grouped_descriptions
  end

  def rds_name_grouped_descriptions
    return @rds_name_grouped_descriptions if @rds_name_grouped_descriptions

    @rds_name_grouped_descriptions = {}
    rds_descriptions.each do |description|
      @rds_name_grouped_descriptions[description[:aws_id]] = description
    end

    @rds_name_grouped_descriptions
  end

  def description_for_name name
    ec2_name_grouped_descriptions[name] || rds_name_grouped_descriptions[name]
  end
end