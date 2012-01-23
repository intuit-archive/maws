#!/usr/bin/env ruby

require 'lib/logger'

require 'rubygems'

require 'lib/mash'
require 'lib/core_ext/object'

require 'lib/loader'


begin
  # optional awesome print
  require 'ap'
rescue LoadError
  def ap(x)
    p x
  end
end

base_path = File.dirname(__FILE__)
cc_path = 'config/config.yml'

Loader.new(base_path, cc_path).load_and_run


