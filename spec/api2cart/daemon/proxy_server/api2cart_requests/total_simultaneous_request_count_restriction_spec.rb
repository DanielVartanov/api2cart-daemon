describe Api2cart::Daemon::ProxyServer do
  let(:remote_server) { InspectableMockServer.new(4096, '') }
  let(:daemon_proxy) { Api2cart::Daemon::ProxyServer.new(2048) }

  before do
    Celluloid.shutdown
    Celluloid.boot
  end

  before do
    remote_server.run_async
    daemon_proxy.run_async
  end

  after do
    Celluloid::Actor.kill(daemon_proxy)
    Celluloid::Actor.kill(remote_server)

    sleep 0.05
  end

  def request_to_random_store
    "http://localhost:4096/v1.0/product.count.json?store_key=#{rand}"
  end

  def make_async_request(request_url)
    Thread.new do
      HTTP.via('localhost', 2048).get(request_url)
    end
    sleep 0.05 # TODO: invent something more clever than this
  end

  # Exception in block

  context 'when it is an API2Cart request' do
    describe 'total simultaneous request count restriction' do
      context 'given maximum allowed amount of simultaneous requests is 20' do
        context 'when I make 20 requests to different stores' do
          before do
            20.times { make_async_request(request_to_random_store) }
          end

          specify 'they all reach remote server' do
            expect(remote_server.request_queue.count).to eq 20
          end

          context 'when I make more requests' do
            before do
              3.times { make_async_request(request_to_random_store) }
            end

            it 'does not reach the server' do
              expect(remote_server.request_queue.count).to eq 20
            end

            context 'when first request is complete' do
              before { remote_server.respond_to_first }

              specify '21st request reached the server' do
                expect(remote_server.request_queue.count).to eq 20
              end
            end
          end
        end
      end
    end
  end
end