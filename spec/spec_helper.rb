require 'hashie'

class Hashie::Mash
  # undef :count if defined? :count
end

def mash x
  Hashie::Mash.new x
end

def aws_test_key
  # file = 'config/aws_test.key'
  # *File.read(file).lines.map {|l| l.chomp}
  return 'no', 'good'
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