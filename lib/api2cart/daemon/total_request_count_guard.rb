module Api2cart::Daemon
  class TotalRequestCountGuard
    def initialize
      self.queued_request_counter = RequestCounter.new
      self.waiting_queue = []
    end

    def guard
      response = queued_request_counter.count_request do
        wait_in_queue! if queued_request_counter.request_count > Api2cart::Daemon.total_request_quota
        yield
      end

      move_queue!
      response
    end

    protected

    attr_accessor :requests_currently_running, :waiting_queue, :queued_request_counter

    def move_queue!
      return if waiting_queue.empty?

      first_in_waiting_queue = waiting_queue.shift
      first_in_waiting_queue.signal
    end

    def wait_in_queue!
      LOGGER.debug "Waiting for overall quota (currently #{queued_request_counter.request_count} requests are queued)"
      condition = Celluloid::Condition.new
      waiting_queue << condition
      condition.wait
    end
  end
end
