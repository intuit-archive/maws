require 'lib/command'
require 'lib/trollop'

class Wait < Command
  def add_specific_options(parser)
    parser.opt :state, "State to wait for", :type => :string
    parser.opt :wait, "Max wait (seconds)", :default => 60
    parser.opt :count, "Minimum number of instances that must match the state", :default => 0
    parser.opt :quiet, "Be quiet", :type => :flag, :default => false
    parser.opt :growl, "Growl notify when done", :type => :flag, :default => false

  end

  def verify_options
    super
    state = options.state
    Trollop::die "Can't wait for blank state" if state.nil? || state.empty?
  end

  def run!
    at_exit do
      if options.growl
        system("growlnotify -m 'waiting for AWS state #{options.state} done'")
      end
    end

    state = options.state
    been_waiting = 0
    total_count = specified_instances.count
    wait_for_count = options.count == 0 ? total_count : options.count
    info "waiting #{options.wait} seconds or until #{wait_for_count}/#{total_count} are #{state}..."
    loop do
      trap("INT") { info "...done (interrupted)"; return }
      return if been_waiting >= options.wait
      left_to_wait = options.wait - been_waiting
      matching_count = specified_instances.select{|i| i.has_approximate_status?(state)}.count
      if matching_count >= wait_for_count
        info "...done (#{matching_count}/#{total_count} are #{state})"
        return
      end

      if options.quiet
        print "."
        $stdout.flush
      else
        info "#{matching_count}/#{total_count} are #{state} - wait #{left_to_wait} seconds or until #{wait_for_count}/#{total_count} are #{state}..."
      end


      sleep 1
      been_waiting += 1
      connection.clear_cached_descriptions
      connection.silent = true
      specified_instances.each {|i| i.sync!}
    end
  end
end