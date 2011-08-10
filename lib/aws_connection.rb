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
end