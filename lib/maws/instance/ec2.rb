require 'maws/instance'
require 'maws/ssh'

# for EC2 instances aws_id is a random id
# name is a value of 'Name' tag
class Instance::EC2 < Instance
  def create
    return if alive?
    info "creating EC2 #{name}..."
    image_id = config(:image_id) || connection.image_id_for_image_name(config(:image_name))
    if image_id.nil?
      info "no AMI id found with name '#{config(:image_name)}'"
      return
    end

    results = connection.ec2.launch_instances(image_id,
      :availability_zone => region_physical_zone,
      :key_name => config(:keypair),
      :min_count => 1,
      :max_count => 1,
      :group_names => security_groups,
      :user_data => config(:user_data),
      :monitoring_enabled => config(:monitoring_enabled),
      :instance_type => config(:instance_type))


    self.description = Description::EC2.new(results.first)
  end

  def set_prefix(prefix)
    @prefix = prefix
    old_name = @name
    @name = self.class.name_for(@config, @prefix, @zone, @role, @index)

    info "renaming #{old_name} to #{@name}"
    create_tags
  end

  def create_tags
    tag_instance_name
    tag_volumes_names

    info "...done (#{name} or #{aws_id} is ready)"
  end

  def tag_instance_name
    retries_left = 20
    loop do
      begin
        connection.ec2.create_tags(aws_id, {'Name' => name})
        info "tagged EC2 instance #{aws_id} as #{name}"
        return
      rescue RightAws::AwsError => error
        if error.message =~ /^InvalidInstanceID.NotFound/
          info "TAGGING FAILED. RETRYING..."
        else
          raise error
        end
      end

      retries_left -= 1
      retries_left > 0 ? sleep(1) : break
    end
    error "Couldn't not tag #{aws_id} with name #{name}. It might not exist on AWS"
  end

  def tag_volumes_names
    # wait a while before volume_ids are made available on the aws ec2 description
    retries_left = 30
    loop do
      if volume_ids.count > 0
        # tag and return
        volume_ids.each {|vid|
          connection.ec2.create_tags(vid, {'Name' => name})
          info "tagged EBS volume #{vid} as #{name}"
        }
        return
      end

      # resync all descriptions (volume ids should appear if missing)
      @maws.resync_instances

      retries_left -= 1
      retries_left > 0 ? sleep(1) : break
    end
    error "No volumes found for #{name} (#{aws_id})"
  end

  def destroy
    return unless alive?
    connection.ec2.terminate_instances(aws_id)
    info "destroying EC2 #{name} (#{aws_id})"
  end

  def stop
    return unless alive?
    if status == 'running'
      connection.ec2.stop_instances(aws_id)
      info "stopping EC2 #{name} (#{aws_id})"
    end
  end

  def start
    return unless alive?
    if status == 'stopped'
      connection.ec2.start_instances(aws_id)
      info "starting EC2 #{name} (#{aws_id})"
    end
  end

  def ssh_available?
    return false unless alive? && self.dns_name && !self.dns_name.empty?

    begin
      3.times { # retry on host unreachable errors
        begin
          Net::SSH.start(dns_name, "phoneyuser", {:auth_methods => ["publickey"], :timeout => 1, :keys_only => true })
        rescue Errno::EHOSTUNREACH
          sleep 2
        end
      }
    rescue Net::SSH::AuthenticationFailed
      return true
    rescue Object
      return false
    end
  end

  def volume_ids
    description.ebs_volume_ids
  end

  def attached_volumes
    description.attached_ebs_volume_ids
  end

  def service
    :ec2
  end

  def display_fields
    super + [:dns_name, :aws_instance_id, :aws_image_id]
  end
end
