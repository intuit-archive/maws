class RightAWSLogger
  def error str
    $stderr.puts "[ERROR]: #{str}"
  end

  def warn str
    puts "[warning]: #{str}"
  end

  def info str
    puts "---- " + str.to_s
  end

  def debug str
    puts str
  end
end

class MawsLogger
  def error str
    $stderr.puts "[ERROR]: #{str}"
  end

  def warn str
    puts "[warning]: #{str}"
  end

  def info str
    puts str
  end

  def debug str
    puts str
  end
end

$logger ||= MawsLogger.new
$right_aws_logger ||= RightAWSLogger.new


def info str
  $logger.info str
end

def error str
  $logger.error str
end

def warn str
  $logger.warn str
end
