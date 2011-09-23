require 'lib/command'

class Create < Command
  def run!
    specified_instances.each {|i| i.create}
    # create tags
    if specified_instances.find_all {|i| i.respond_to?(:create_tags) && i.alive?}.count > 0
      sleep 6
      connection.clear_cached_descriptions
      specified_instances.each {|i| i.create_tags if i.respond_to?(:create_tags) && i.alive?}
    end
  end
end