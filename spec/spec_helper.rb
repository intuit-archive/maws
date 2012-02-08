require 'maws/mash'


unless defined? SPEC_PATH
  SPEC_PATH = File.dirname(__FILE__)
  # for testing purposes, it's like the whole application lives inside tmp/spec_maws_root/ folder
  SPEC_BASE_PATH = File.expand_path(SPEC_PATH + "/../tmp/spec_maws_root")
  BASE_PATH = SPEC_BASE_PATH

  KEYPAIRS_PATH = SPEC_BASE_PATH + "/config/keypairs"
end

def aws_test_key
  # file = 'config/aws_test.key'
  # *File.read(file).lines.map {|l| l.chomp}
  return 'no', 'good'
end

def mock_config
  @config = mash()
  @config.aws_key = mash({:key_id => "keyid", :secret_key => "secretkey"})
  @config.region = "test-region-1"

  @config
end

class SpecLogger
  def initialize
    @log_path = "logs/spec.log"
    @log_file = File.open(@log_path, "w")
    at_exit {@log_file.close}
  end

  def info str
    @log_file.puts "[info] " + str.to_s
  end

  def error str
    @log_file.puts "[ERROR] " + str.to_s
  end

  def warn str
    @log_file.puts "[warn] " + str.to_s
  end

  def debug str
    @log_file.puts "[debug] " + str.to_s
  end

end


unless $logger
  $logger = $right_aws_logger = SpecLogger.new
end