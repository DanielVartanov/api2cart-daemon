describe Api2cart::Daemon::ProxyServer do
  let(:mock_server) { InspectableMockServer.new(4096, '') }
  let(:daemon_proxy) { Api2cart::Daemon::ProxyServer.new(2048) }

  before do
    Celluloid.shutdown
    Celluloid.boot
  end

  before do
    mock_server.run_async
    daemon_proxy.run_async
  end

  after do
    Celluloid::Actor.kill(daemon_proxy)
    Celluloid::Actor.kill(mock_server)

    sleep 0.05
  end

  def request_to_random_store
    "http://localhost:4096/v1.0/product.count.json?store_key=#{rand}"
  end

  context 'when it is an API2Cart request' do
    describe 'total simultaneous request count restriction' do
      context 'given maximum allowed amount of simultaneous requests is 20' do
        context 'when I make 20 requests to different stores' do
          before do
            20.times { make_async_request(request_to_random_store) }
            mock_server.wait_for_number_of_requests(20)
          end

          specify 'they all reach remote server' do
            expect(mock_server.request_queue.count).to eq 20
          end

          context 'when I make more requests' do
            before do
              mock_server.wait_for_number_of_requests(20)
              3.times { make_async_request(request_to_random_store) }
              sleep 0.05
            end

            it 'does not reach the server' do
              expect(mock_server.request_queue.count).to eq 20
            end

            context 'when first request is complete' do
              before do
                mock_server.respond_to_first
                mock_server.wait_for_number_of_requests(21)
              end

              specify '21st request reached the server' do
                expect(mock_server.request_queue.count).to eq 20
              end
            end
          end
        end
      end
    end
  end
end
