require 'lib/command'
require 'lib/trollop'

class Wait < Command
  def add_specific_options(parser)
    parser.opt :state, "State to wait for", :type => :string
    parser.opt :wait, "Max wait (seconds)", :default => 60
  end

  def verify_options
    state = options.state
    Trollop::die "Can't wait for blank state" if state.nil? || state.empty?
  end

  def run!
    state = options.state
    been_waiting = 0
    loop do
      return if been_waiting >= options.wait
      matching = @selected_instances.map {|i| i.has_approximate_status?(state)}
      total_count = matching.count
      true_count = matching.select{|x| x}.count
      info "#{true_count}/#{total_count} are #{state}"
      return if total_count == true_count

      sleep 1
      been_waiting += 1
      connection.clear_cached_descriptions
      @selected_instances.each {|i| i.sync}
    end

  end
end