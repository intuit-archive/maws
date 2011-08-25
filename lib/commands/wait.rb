require 'lib/command'
require 'lib/trollop'

class Wait < Command
  def add_specific_options(parser)
    parser.opt :state, "State to wait for", :type => :string
    parser.opt :wait, "Max wait (seconds)", :default => 60
    parser.opt :count, "Minimum number of instances that must match the state", :default => 0
  end

  def verify_options
    state = options.state
    Trollop::die "Can't wait for blank state" if state.nil? || state.empty?
  end

  def run!
    state = options.state
    been_waiting = 0
    total_count = specified_instances.count
    wait_for_count = options.count == 0 ? total_count : options.count
    loop do
      return if been_waiting >= options.wait
      left_to_wait = options.wait - been_waiting
      matching_count = specified_instances.select{|i| i.has_approximate_status?(state)}.count
      if matching_count >= wait_for_count
        info "...done (#{matching_count}/#{total_count} are #{state})"
        return
      end

      info "#{matching_count}/#{total_count} are #{state} - wait #{left_to_wait} seconds or until #{wait_for_count}/#{total_count} are #{state}..."

      sleep 1
      been_waiting += 1
      connection.clear_cached_descriptions
      specified_instances.each {|i| i.sync}
    end

  end
end