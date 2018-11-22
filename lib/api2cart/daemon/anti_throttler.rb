module Api2cart::Daemon
  class AntiThrottler
    def initialize
      total_request_count_guard = TotalRequestCountGuard.new
      self.requests_per_store_guard = RequestsPerStoreGuard.new total_request_count_guard
    end

    def prevent_throttling(http_message)
      # TODO: Temporary debug message to find out
      # a problematic requests
      LOGGER.debug(http_message.inspect) if http_message.request_params.nil?

      store_key = http_message.request_params['store_key']
      api_key = http_message.request_params['api_key']
      request_host = http_message.request_host
      request_port = http_message.request_port

      requests_per_store_guard.guard(store_key, api_key, request_host, request_port) { yield }
    end

    protected

    attr_accessor :requests_per_store_guard
  end
end
