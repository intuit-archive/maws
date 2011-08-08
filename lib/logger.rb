def info str
  puts str
end

def error str
  $stderr.puts "[ERROR]: #{str}" 
end

def warn str
  puts "[warning]: #{str}" 
end