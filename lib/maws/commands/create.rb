require 'maws/command'

class Create < Command
  def description
    "create - creates all specified instances if they don't exist"
  end

  def run!
    instances_to_create = instances.specified.not_alive
    if instances_to_create.empty?
      info "nothing to create"
      return
    end

    instances_to_create.each {|i| i.create}

    # create tags
    instances_to_be_tagged =  instances_to_create.alive.with_service(:ec2)
    unless instances_to_be_tagged.empty?
      sleep 2
      # connection.silent = true
      instances_to_be_tagged.each {|i| i.create_tags}
    end
  end
end