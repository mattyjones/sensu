class TestSensuAPI < TestCase
  def setup
    super
    @api_uri = 'http://' + @settings[:api][:host] + ':' + @settings[:api][:port].to_s
    @request_options = {
      :head => {
        :authorization => [
          @settings[:api][:user],
          @settings[:api][:password]
        ]
      }
    }
  end

  def test_get_info
    Sensu::API.run_test(@options) do
      http = EM::HttpRequest.new(@api_uri + '/info').get(@request_options)
      http.callback do
        assert_equal(200, http.response_header.status)
        info = JSON.parse(http.response, :symbolize_names => true)
        assert_equal(Sensu::VERSION, info[:sensu][:version])
        assert_equal('ok', info[:health][:redis])
        assert_equal('ok', info[:health][:rabbitmq])
        done
      end
    end
  end

  def test_get_events
    Sensu::API.run_test(@options) do
      http = EM::HttpRequest.new(@api_uri + '/events').get(@request_options)
      http.callback do
        assert_equal(200, http.response_header.status)
        events = JSON.parse(http.response, :symbolize_names => true)
        assert(events.is_a?(Array))
        assert_block "Response didn't contain the test event" do
          events.any? do |event|
            if event[:client] == @settings[:client][:name]
              event[:check] == 'test'
            end
          end
        end
        done
      end
    end
  end

  def test_get_client_events
    Sensu::API.run_test(@options) do
      http = EM::HttpRequest.new(@api_uri + '/events/' + @settings[:client][:name]).get(@request_options)
      http.callback do
        assert_equal(200, http.response_header.status)
        events = JSON.parse(http.response, :symbolize_names => true)
        assert(events.is_a?(Array))
        assert_block "Response didn't contain the test event" do
          events.any? do |event|
            event[:check] == 'test'
          end
        end
        done
      end
    end
  end

  def test_get_clients
    Sensu::API.run_test(@options) do
      http = EM::HttpRequest.new(@api_uri + '/clients').get(@request_options)
      http.callback do
        assert_equal(200, http.response_header.status)
        clients = JSON.parse(http.response, :symbolize_names => true)
        assert(clients.is_a?(Array))
        assert_block "Response didn't contain the test client" do
          clients.any? do |client|
            client[:name] == @settings[:client][:name]
          end
        end
        done
      end
    end
  end

  def test_get_checks
    Sensu::API.run_test(@options) do
      http = EM::HttpRequest.new(@api_uri + '/checks').get(@request_options)
      http.callback do
        assert_equal(200, http.response_header.status)
        checks = JSON.parse(http.response, :symbolize_names => true)
        assert_equal($settings.checks, checks)
        done
      end
    end
  end

  def test_get_event
    Sensu::API.run_test(@options) do
      http = EM::HttpRequest.new(@api_uri + '/event/' + @settings[:client][:name] + '/test').get(@request_options)
      http.callback do
        assert_equal(200, http.response_header.status)
        expected = {
          :client => @settings[:client][:name],
          :check => 'test',
          :output => 'CRITICAL',
          :status => 2,
          :flapping => false,
          :occurrences => 1
        }
        event = sanitize_keys(JSON.parse(http.response, :symbolize_names => true))
        assert_equal(expected, event)
        done
      end
    end
  end

  def test_delete_event
    Sensu::API.run_test(@options) do
      http = EM::HttpRequest.new(@api_uri + '/event/' + @settings[:client][:name] + '/test').delete(@request_options)
      http.callback do
        assert_equal(202, http.response_header.status)
        done
      end
    end
  end

  def test_resolve_event
    Sensu::API.run_test(@options) do
      options = {
        :body => {
          :client => @settings[:client][:name],
          :check => 'test'
        }.to_json
      }
      request_options = @request_options.merge(options)
      http = EM::HttpRequest.new(@api_uri + '/resolve').post(request_options)
      http.callback do
        assert_equal(202, http.response_header.status)
        done
      end
    end
  end

  def test_resolve_nonexistent_event
    Sensu::API.run_test(@options) do
      options = {
        :body => {
          :client => @settings[:client][:name],
          :check => 'nonexistent'
        }.to_json
      }
      request_options = @request_options.merge(options)
      http = EM::HttpRequest.new(@api_uri + '/resolve').post(request_options)
      http.callback do
        assert_equal(404, http.response_header.status)
        done
      end
    end
  end

  def test_resolve_event_malformed
    Sensu::API.run_test(@options) do
      options = {
        :body => 'malformed'
      }
      request_options = @request_options.merge(options)
      http = EM::HttpRequest.new(@api_uri + '/resolve').post(request_options)
      http.callback do
        assert_equal(400, http.response_header.status)
        done
      end
    end
  end

  def test_resolve_event_missing_data
    Sensu::API.run_test(@options) do
      options = {
        :body => {
          :client => @settings[:client][:name]
        }.to_json
      }
      request_options = @request_options.merge(options)
      http = EM::HttpRequest.new(@api_uri + '/resolve').post(request_options)
      http.callback do
        assert_equal(400, http.response_header.status)
        done
      end
    end
  end

  def test_get_client
    Sensu::API.run_test(@options) do
      http = EM::HttpRequest.new(@api_uri + '/client/' + @settings[:client][:name]).get(@request_options)
      http.callback do
        assert_equal(200, http.response_header.status)
        client = sanitize_keys(JSON.parse(http.response, :symbolize_names => true))
        assert_equal(@settings[:client], client)
        done
      end
    end
  end

  def test_get_nonexistent_client
    Sensu::API.run_test(@options) do
      http = EM::HttpRequest.new(@api_uri + '/client/nonexistent').get(@request_options)
      http.callback do
        assert_equal(404, http.response_header.status)
        done
      end
    end
  end

  def test_delete_client
    Sensu::API.run_test(@options) do
      http = EM::HttpRequest.new(@api_uri + '/client/' + @settings[:client][:name]).delete(@request_options)
      http.callback do
        assert_equal(202, http.response_header.status)
        done
      end
    end
  end

  def test_delete_nonexistent_client
    Sensu::API.run_test(@options) do
      http = EM::HttpRequest.new(@api_uri + '/client/nonexistent').delete(@request_options)
      http.callback do
        assert_equal(404, http.response_header.status)
        done
      end
    end
  end

  def test_get_check
    Sensu::API.run_test(@options) do
      http = EM::HttpRequest.new(@api_uri + '/check/tokens').get(@request_options)
      http.callback do
        assert_equal(200, http.response_header.status)
        expected = @settings[:checks][:tokens].merge(:name => 'tokens')
        check = JSON.parse(http.response, :symbolize_names => true)
        assert_equal(expected, check)
        done
      end
    end
  end

  def test_get_nonexistent_check
    Sensu::API.run_test(@options) do
      http = EM::HttpRequest.new(@api_uri + '/check/nonexistent').get(@request_options)
      http.callback do
        assert_equal(404, http.response_header.status)
        done
      end
    end
  end

  def test_check_request
    Sensu::API.run_test(@options) do
      options = {
        :body => {
          :check => 'tokens',
          :subscribers => [
            'test'
          ]
        }.to_json
      }
      request_options = @request_options.merge(options)
      http = EM::HttpRequest.new(@api_uri + '/request').post(request_options)
      http.callback do
        assert_equal(201, http.response_header.status)
        done
      end
    end
  end

  def test_check_request_malformed
    Sensu::API.run_test(@options) do
      options = {
        :body => {
          :check => 'tokens',
          :subscribers => 'malformed'
        }.to_json
      }
      request_options = @request_options.merge(options)
      http = EM::HttpRequest.new(@api_uri + '/request').post(request_options)
      http.callback do
        assert_equal(400, http.response_header.status)
        done
      end
    end
  end

  def test_check_request_missing_data
    Sensu::API.run_test(@options) do
      options = {
        :body => {
          :check => 'tokens'
        }.to_json
      }
      request_options = @request_options.merge(options)
      http = EM::HttpRequest.new(@api_uri + '/request').post(request_options)
      http.callback do
        assert_equal(400, http.response_header.status)
        done
      end
    end
  end

  def test_create_stash
    Sensu::API.run_test(@options) do
      options = {
        :body => {
          :key => 'value'
        }.to_json
      }
      request_options = @request_options.merge(options)
      http = EM::HttpRequest.new(@api_uri + '/stash/tester').post(request_options)
      http.callback do
        assert_equal(201, http.response_header.status)
        done
      end
    end
  end

  def test_get_stash
    Sensu::API.run_test(@options) do
      http = EM::HttpRequest.new(@api_uri + '/stash/test/test').get(@request_options)
      http.callback do |response|
        assert_equal(200, http.response_header.status)
        done
      end
    end
  end

  def test_get_stashes
    Sensu::API.run_test(@options) do
      http = EM::HttpRequest.new(@api_uri + '/stashes').get(@request_options)
      http.callback do
        assert_equal(200, http.response_header.status)
        stashes = JSON.parse(http.response)
        assert(stashes.is_a?(Array))
        assert_block "Response didn't contain a test stash" do
          stashes.any? do |path, stash|
            ['test/test', 'tester'].include?(path)
          end
        end
        done
      end
    end
  end

  def test_multi_get_stashes
    Sensu::API.run_test(@options) do
      options = {
        :body => [
          'test/test',
          'tester'
        ].to_json
      }
      request_options = @request_options.merge(options)
      http = EM::HttpRequest.new(@api_uri + '/stashes').post(request_options)
      http.callback do
        assert_equal(200, http.response_header.status)
        stashes = JSON.parse(http.response)
        assert(stashes.is_a?(Hash))
        assert_block "Response didn't contain a test stash" do
          stashes.any? do |path, stash|
            ['test/test', 'tester'].include?(path)
          end
        end
        done
      end
    end
  end

  def test_delete_stash
    Sensu::API.run_test(@options) do
      http = EM::HttpRequest.new(@api_uri + '/stash/test/test').delete(@request_options)
      http.callback do |response|
        assert_equal(204, http.response_header.status)
        done
      end
    end
  end
end
