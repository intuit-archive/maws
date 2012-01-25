Gem::Specification.new do |s|
  s.name          = 'maws'
  s.version       = '0.8.2'
  s.date          = '2012-01-24'
  s.summary       = "MAWS"
  s.description   = "Tool set for provisioning and managing AWS infrastructures"
  s.authors       = ["Juozas Gaigalas", "Vinu Somayaji", "Bradly Feeley"]
  s.email         = 'juozasgaigalas@gmail.com'
  s.files         = Dir['lib/**/*.rb']
  s.executables   << 'maws'
  s.homepage      = "http://github.com/live-community/maws"

  s.add_runtime_dependency 'right_aws', '= 3.0.0'
  s.add_runtime_dependency 'hashie'
  s.add_runtime_dependency 'erubis'
  s.add_runtime_dependency 'net-ssh', ">= 2.2.0"
  s.add_runtime_dependency 'net-scp'
  s.add_runtime_dependency 'terminal-table'

  s.add_development_dependency 'rspec'
end