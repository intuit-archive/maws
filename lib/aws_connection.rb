# require 'right_aws'
require '/Users/jgaigalas/src/right_aws/lib/right_aws'
require 'lib/logger'

class AwsConnection
  def initialize(keyid, key)
    @access_key_id = keyid
    @secret_key = key

    @params = {:region => 'us-west-1', :logger => $logger}
  end

  def ec2
    @ec2 ||= RightAws::Ec2.new(@access_key_id, @secret_key, @params.dup)
  end

  def rds
    @rds ||= RightAws::RdsInterface.new(@access_key_id, @secret_key, @params.dup)
  end

  def ec2_name_grouped_descriptions
    return @ec2_name_grouped_descriptions if @ec2_name_grouped_descriptions

    info "Fetching all EC2 instances info from AWS..."
    descriptions = ec2.describe_instances
    @ec2_name_grouped_descriptions = {}
    descriptions.each do |description|
      name = description[:tags]["Name"] || description[:aws_instance_id]
      @ec2_name_grouped_descriptions[name] = description
    end
    info "...done"
    @ec2_name_grouped_descriptions
  end

  def rds_name_grouped_descriptions
    @rds_name_grouped_descriptions ||= {}
  end

  def description_for_name name
    ec2_name_grouped_descriptions[name] || rds_name_grouped_descriptions[name]
  end
end