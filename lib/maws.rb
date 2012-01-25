require 'maws/logger'
require 'maws/mash'
require 'maws/core_ext/object'

require 'maws/loader'


begin
  # optional awesome print
  require 'ap'
rescue LoadError
  def ap(x)
    p x
  end
end


class Maws
  def self.load_and_run!
    base_path = Dir.pwd
    cc_path = 'maws.yml'

    Loader.new(base_path, cc_path).load_and_run
  end
end
