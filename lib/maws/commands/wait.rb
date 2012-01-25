require 'maws/command'
require 'maws/trollop'

class Wait < Command
  def description
    "wait - do nothing until specified instances enter specified state, then quite and notify"
  end

  def add_specific_options(parser)
    parser.opt :target_state, "State to wait for", :type => :string
    parser.opt :wait, "Max wait (seconds)", :default => 60
    parser.opt :count, "Minimum number of specified instances that must match the state", :default => 0
    parser.opt :quiet, "Be quiet", :type => :flag, :default => false
    parser.opt :growl, "Growl notify when done", :type => :flag, :default => false
  end

  def verify_options
    super
    state = @config.command_line.target_state
    Trollop::die "Can't wait for blank state" if state.nil? || state.empty?
  end

  def run!
    at_exit do
      if @config.command_line.growl
        system("growlnotify -m 'waiting for AWS state #{@config.command_line.target_state} done'")
      end
    end

    state = @config.command_line.target_state
    been_waiting = 0
    wait_for_count = @config.command_line.count == 0 ? instances.specified.count : @config.command_line.count
    wait_for_time = @config.command_line.wait

    info "waiting #{wait_for_time} seconds or until #{wait_for_count} are #{state}..."

    loop do
      trap("INT") { info "...done (interrupted)"; return }
      return if been_waiting >= wait_for_time
      left_to_wait = wait_for_time - been_waiting
      matching_count = instances.specified.with_approximate_status(state).count

      if matching_count >= wait_for_count
        info "...done (#{matching_count}/#{wait_for_count} are #{state})"
        return
      end

      if @config.command_line.quiet
        print "."
        $stdout.flush
      else
        info "#{matching_count}/#{wait_for_count} are #{state} - wait #{left_to_wait} seconds or until #{wait_for_count}/#{wait_for_count} are #{state}..."
      end


      sleep 1
      been_waiting += 1
      @maws.resync_instances
    end
  end
end