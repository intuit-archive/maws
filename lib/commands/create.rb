require 'lib/command'

class Create < Command
  def run!
    already_alive_instances = specified_instances.find_all {|i| i.alive?}
    specified_instances.each {|i| i.create}

    # create tags
    instances_to_be_tagged =  specified_instances.find_all {|i| !already_alive_instances.include?(i) && i.respond_to?(:create_tags) && i.alive?}
    unless instances_to_be_tagged.empty?
      sleep 2
      connection.silent = true
      instances_to_be_tagged.each {|i| i.create_tags}
    end
  end
end