require 'uri'

module Api2cart::Daemon
  class ProxyConnectionHandler < Struct.new(:anti_throttler)
    def handle_proxy_connection(client_socket)
      http_message = read_http_message(client_socket)
      response = compose_response_for(http_message)
      send_response_to_client(client_socket, response)
    end

    protected

    def compose_response_for(http_message)
      return bad_request if not_proxy_request?(http_message)

      anti_throttler.prevent_throttling(http_message) { request_remote_server(http_message) }
    end

    def request_remote_server(http_message)
      processed_message = process_client_request(http_message)
      send_request_to_remote_server(http_message.request_host, http_message.request_port, processed_message)
    end

    def process_client_request(client_request)
      parsed_request_url = URI.parse client_request.request_url
      client_request.message.gsub client_request.request_url, parsed_request_url.request_uri
    end

    def read_http_message(socket)
      HTTPMessageReader.new(socket).read_http_message
    end

    def send_request_to_remote_server(host, port, request)
      remote_server_socket = Celluloid::IO::TCPSocket.new host, port
      remote_server_socket.write request
      read_http_message(remote_server_socket).message
    rescue Exception => e
      LOGGER.error "! Problem connecting to server: #{e.inspect}"
      internal_server_error(e)
    ensure
      remote_server_socket.close
    end

    def send_response_to_client(client_socket, response)
      client_socket.write response
    end

    def not_proxy_request?(http_message)
      URI.parse(http_message.request_url).host.nil?
    end

    def internal_server_error(exception)
      <<MESSAGE + exception.inspect
HTTP/1.1 500 Internal Server Error
Content-Length: #{exception.inspect.bytesize}
Connection: close
Status: 500 Internal Server Error

MESSAGE
    end

    def bad_request
      <<MESSAGE
HTTP/1.1 400 Bad Request
Content-Length: 0
Connection: close
Status: 400 Bad Request

MESSAGE
    end
  end
end
