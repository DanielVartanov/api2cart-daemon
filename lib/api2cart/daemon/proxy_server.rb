require 'celluloid/io'

module Api2cart::Daemon
  class ProxyServer < Struct.new(:port)
    include Celluloid::IO

    def run
      accept_connections bind_proxy_socket
    end

    def run_async
      async.accept_connections bind_proxy_socket
    end

    protected

    def bind_proxy_socket
      TCPServer.new('', port).tap do
        LOGGER.info "API2Cart Daemon is running at 0.0.0.0:#{port}"
      end
    end

    def accept_connections(proxy_socket)
      loop { async.handle_connection proxy_socket.accept }
    end

    def handle_connection(client_socket)
      begin
        connection_handler.handle_proxy_connection(client_socket)
      rescue Exception => e
        LOGGER.error "! Exception: #{e.inspect}\n#{e.backtrace}"
      ensure
        client_socket.close
      end
    end

    def connection_handler
      @connection_handler ||= ProxyConnectionHandler.new(anti_throttler)
    end

    def anti_throttler
      @anti_throttler ||= AntiThrottler.new
    end
  end
end
