# frozen_string_literal: true

RSpec.describe Aganakti::Query do
  def with_stub_server(replies)
    StubServer.open(0, replies) do |server|
      server.wait

      yield server.instance_variable_get(:@server)[:Port]
    end
  end

  describe '::BOOL_SETTING_METHODS' do
    it 'cannot be accessed normally because it is a private constant' do
      expect { described_class::BOOL_SETTING_METHODS }.to raise_error(NameError, /private constant .*BOOL_SETTING_METHODS referenced/)
    end

    it 'is frozen if we access the private constant anyways' do
      expect(described_class.const_get(:BOOL_SETTING_METHODS)).to be_frozen
    end
  end

  describe '::WITH_WITHOUT_PREFIX' do
    it 'is a private constant' do
      expect { described_class::WITH_WITHOUT_PREFIX }.to raise_error(NameError, /private constant .* referenced/)
    end

    it 'is frozen' do
      expect(described_class.const_get(:WITH_WITHOUT_PREFIX)).to be_frozen
    end

    it 'matches what we expect' do
      expect(described_class.const_get(:WITH_WITHOUT_PREFIX)).to eq(/\A(with|without)_/)
    end
  end

  describe '.new', :stubbed_request do
    let(:uuid) { '24f65557-b6e9-4d0c-8962-3bfe711581f5' }

    before do
      allow(Oj).to receive(:dump).and_call_original.once
      allow(SecureRandom).to receive(:uuid).and_return(uuid)
    end

    %w[priority sqlTimeZone useApproximateCountDistinct useApproximateTopN useCache].each do |field|
      it "ensures #{field} isn't passed in the query context by default" do
        query.result

        expect(Oj).to have_received(:dump).with(
          hash_including(
            context: hash_excluding(field.to_sym)
          ),
          mode: :strict
        )
      end
    end

    it 'generates a random query UUID' do
      query.result

      expect(Oj).to have_received(:dump).with(
        hash_including(
          context: hash_including(sqlQueryId: uuid)
        ),
        mode: :strict
      )
    end
  end

  describe '#executed?', :stubbed_request do
    context 'with a query that #result has been called on' do
      before do
        query.result
      end

      it('returns true') { expect(query.executed?).to be true }
    end

    context 'with a query that #result has never been called on' do
      it('returns false') { expect(query.executed?).to be false }
    end
  end

  describe '#includes_column?', :stubbed_request do
    if ActiveRecord::VERSION::MAJOR >= 6
      context 'when running using ActiveRecord >= 6' do
        before do
          allow(result).to receive(:includes_column?).once
        end

        it 'delegates to result#includes_column?' do
          query.public_send(:includes_column?, 'dummy')

          expect(result).to have_received(:includes_column?).once
        end

        it 'is properly identified as existing via #respond_to?' do
          expect(query).to respond_to(:includes_column?)
        end
      end
    else
      context 'when running using ActiveRecord < 6' do
        it "doesn't work" do
          expect { query.includes_column?('dummy') }.to raise_error(NoMethodError)
        end

        it 'is properly identified as missing via #respond_to?' do
          expect(query).not_to respond_to(:includes_column?)
        end
      end
    end
  end

  describe '#result' do
    # this returns a lambda to allow the client to be built after the server starts
    subject(:query) do
      ->(client) { described_class.new(client, 'SELECT server_type, COUNT(*) FROM sys.servers GROUP BY server_type ORDER BY 2 DESC', []) }
    end

    let(:error_response) do
      '{"error":"Plan validation failed","errorMessage":"org.apache.calcite.runtime.CalciteContextException: At line 1, column 77: Ordinal out of range",' \
      '"errorClass":"org.apache.calcite.tools.ValidationException","host":null}'
    end

    let(:good_response) do
      <<~RESPONSE
        ["server_type","EXPR$1"]
        ["peon",8]
        ["middle_manager",4]
        ["historical",4]
        ["router",1]
        ["coordinator",1]
        ["overlord",1]
        ["broker",1]

      RESPONSE
    end

    let(:good_result) do
      [
        { 'server_type' => 'peon', 'EXPR$1' => 8 },
        { 'server_type' => 'middle_manager', 'EXPR$1' => 4 },
        { 'server_type' => 'historical', 'EXPR$1' => 4 },
        { 'server_type' => 'router', 'EXPR$1' => 1 },
        { 'server_type' => 'coordinator', 'EXPR$1' => 1 },
        { 'server_type' => 'overlord', 'EXPR$1' => 1 },
        { 'server_type' => 'broker', 'EXPR$1' => 1 }
      ]
    end

    let(:timeout_response) do
      # This returns [rd, wr], which are both open. the reply should use the read stream,
      # and after a delay write to and close the write stream
      IO.pipe
    end

    let(:truncated_response) do
      <<~RESPONSE
        ["server_type","EXPR$1"]
        ["peon",8]
        ["middle_manager",4]
        ["historical",4]
        ["router",1]
        ["coordinator",1]
      RESPONSE
    end

    # Standard response headers that all requests return
    let(:response_headers) do
      {
        'Content-Type' => 'application/json'
      }
    end

    # Replies to set up for stub_server
    let(:replies) do
      {
        '/good' => [200, response_headers, [good_response]],
        '/error' => [400, response_headers, [error_response]],
        '/error2' => [500, {}, ['Internal Server Error']],
        '/error3' => [500, response_headers, ['{"problem":true}']],
        '/timeout' => [200, response_headers, timeout_response.first],
        '/truncated' => [200, response_headers, [truncated_response]]
      }
    end

    context 'when calling once' do
      it "doesn't mark the query as executed when there is an error" do
        with_stub_server(replies) do |port|
          client     = Aganakti.new("http://localhost:#{port}/error")
          live_query = query.call(client)

          expect do
            live_query.to_a
          rescue Aganakti::QueryError
            nil
          end.not_to change { live_query.executed? }.from(false)
        end
      end

      it 'executes the query and parses the results correctly' do
        with_stub_server(replies) do |port|
          client     = Aganakti.new("http://localhost:#{port}/good")
          live_query = query.call(client)

          expect(live_query.to_a).to eq(good_result)
        end
      end

      it 'executes queries with parameters' do
        with_stub_server(replies) do |port|
          client     = Aganakti.new("http://localhost:#{port}/good")
          live_query = described_class.new(
            client,
            'SELECT server_type, COUNT(*) FROM sys.servers WHERE plaintext_port = ? GROUP BY server_type ORDER BY 2 DESC',
            [-1]
          )

          expect(live_query.to_a).to eq(good_result)
        end
      end

      it 'handles cURL errors' do
        with_stub_server(replies) do |port|
          client     = Aganakti.new("https://localhost:#{port}/error")
          live_query = query.call(client)

          expect { live_query.to_a }.to raise_error(Aganakti::QueryError, 'cURL error 35: SSL connect error')
        end
      end

      it 'handles errors which are unparseable and not JSON' do
        with_stub_server(replies) do |port|
          client     = Aganakti.new("http://localhost:#{port}/error2")
          live_query = query.call(client)

          expect { live_query.to_a }.to raise_error(Aganakti::QueryError, "An error occurred, but the server's response was unparseable: " \
                                                                          'Internal Server Error')
        end
      end

      it 'handles errors which are unparseable but still JSON' do
        with_stub_server(replies) do |port|
          client     = Aganakti.new("http://localhost:#{port}/error3")
          live_query = query.call(client)

          expect { live_query.to_a }.to raise_error(Aganakti::QueryError, "An error occurred, but the server's response was unparseable: " \
                                                                          '{"problem":true}')
        end
      end

      it 'handles execution errors' do
        with_stub_server(replies) do |port|
          client     = Aganakti.new("http://localhost:#{port}/error")
          live_query = query.call(client)

          expect { live_query.to_a }.to raise_error(Aganakti::QueryError, 'Plan validation failed: org.apache.calcite.runtime.CalciteContextException: ' \
                                                                          'At line 1, column 77: Ordinal out of range')
        end
      end

      it 'handles query timeouts' do
        with_stub_server(replies) do |port|
          client = Aganakti.new("http://localhost:#{port}/timeout", timeout: 0.1)

          writer_thread = Thread.new do
            # actually make the IO return data
            sleep 1

            wr = timeout_response.last
            wr.write(good_response)
            wr.close
          end

          expect do
            query_thread = Thread.new { query.call(client).to_a }
            query_thread.report_on_exception = false
            query_thread.value
          end.to raise_error(Aganakti::QueryTimedOutError)

          writer_thread.join # so the spec doesn't hang
        end
      end

      it 'handles truncated responses' do
        with_stub_server(replies) do |port|
          client     = Aganakti.new("http://localhost:#{port}/truncated")
          live_query = query.call(client)

          expect { live_query.to_a }.to raise_error(Aganakti::QueryResultTruncatedError)
        end
      end
    end

    context 'when calling more than once' do
      it 'executes the query once and returns cached results otherwise' do
        live_query = nil

        with_stub_server(replies) do |port|
          client     = Aganakti.new("http://localhost:#{port}/good")
          live_query = query.call(client)

          live_query.to_a # run once
        end

        # server is now down, verify our data is cached
        expect(live_query.to_a).to eq(good_result)
      end
    end
  end

  {
    in_time_zone:                       [:sqlTimeZone, 'Foo/Bar'],
    with_approximate_count_distinct:    [:useApproximateCountDistinct, true],
    with_approximate_top_n:             [:useApproximateTopN, true],
    with_cache:                         [:useCache, true],
    with_windowing:                     [:enableWindowing, true],
    with_priority:                      [:priority, 1],
    without_approximate_count_distinct: [:useApproximateCountDistinct, false],
    without_approximate_top_n:          [:useApproximateTopN, false],
    without_cache:                      [:useCache, false],
    without_windowing:                  [:enableWindowing, false]
  }.each_pair do |meth, (json_key, test_arg)|
    # Pick the other method to call to check we don't clobber it
    if %i[with_approximate_count_distinct without_approximate_count_distinct].include?(meth)
      other_key = :useCache
      other_meth = :without_cache
    else
      other_key = :useApproximateCountDistinct
      other_meth = :without_approximate_count_distinct
    end

    # Get a lambda to call to DRY up this spec
    call_meth = if meth.to_s.start_with?('with') && meth != :with_priority
                  ->(query) { query.send(meth) }
                else
                  ->(query) { query.send(meth, test_arg) }
                end

    describe "##{meth}", :stubbed_request do
      before do
        allow(Oj).to receive(:dump).and_call_original.once
      end

      context 'when specified' do
        it "doesn't interact with other flags" do
          call_meth.call(query).send(other_meth).result

          expect(Oj).to have_received(:dump).with(
            hash_including(
              context: hash_including(other_key => false)
            ),
            mode: :strict
          )
        end

        it "sets #{json_key} to #{test_arg.inspect} in the query context" do
          call_meth.call(query).send(other_meth).result

          expect(Oj).to have_received(:dump).with(
            hash_including(
              context: hash_including(json_key => test_arg)
            ),
            mode: :strict
          )
        end
      end

      context 'when not specified' do
        it "doesn't interact with other flags" do
          query.send(other_meth).result

          expect(Oj).to have_received(:dump).with(
            hash_including(
              context: hash_including(other_key => false)
            ),
            mode: :strict
          )
        end

        it "doesn't set #{json_key} in the query context" do
          query.result

          expect(Oj).to have_received(:dump).with(
            hash_including(
              context: hash_excluding(json_key)
            ),
            mode: :strict
          )
        end
      end

      context 'when the query was already executed' do
        it 'raises an Aganakti::QueryAlreadyExecutedError' do
          call_meth.call(query).result

          expect { call_meth.call(query) }.to raise_error(Aganakti::QueryAlreadyExecutedError, /the query has already been executed/)
        end
      end
    end
  end

  %w[[] columns column_types each last length map empty? rows to_ary to_a].each do |del|
    describe "##{del}", :stubbed_request do
      before do
        allow(result).to receive(del.to_sym).once
      end

      it "delegates to result##{del}" do
        if del == '[]'
          query.public_send(del.to_sym, 'dummy')
        else
          query.public_send(del.to_sym)
        end

        expect(result).to have_received(del.to_sym).once
      end

      it 'is properly identified as existing via #respond_to?' do
        expect(query).to respond_to(del.to_sym)
      end
    end
  end

  describe '#with_context', :stubbed_request do
    before do
      allow(Oj).to receive(:dump).and_call_original.once
    end

    context 'when setting custom context parameters' do
      it 'includes the custom context in the query payload' do
        query.with_context(maxScatterGatherBytes: 1_000_000, timeout: 30_000).result

        expect(Oj).to have_received(:dump).with(
          hash_including(
            context: hash_including(
              maxScatterGatherBytes: 1_000_000,
              timeout: 30_000
            )
          ),
          mode: :strict
        )
      end

      it 'converts string keys to symbols' do
        query.with_context('maxScatterGatherBytes' => 1_000_000).result

        expect(Oj).to have_received(:dump).with(
          hash_including(
            context: hash_including(maxScatterGatherBytes: 1_000_000)
          ),
          mode: :strict
        )
      end

      it 'allows chaining' do
        result_query = query.with_context(foo: 1).with_context(bar: 2)

        expect(result_query).to eq(query)
      end

      it 'merges multiple with_context calls' do
        query.with_context(foo: 1).with_context(bar: 2).result

        expect(Oj).to have_received(:dump).with(
          hash_including(
            context: hash_including(foo: 1, bar: 2)
          ),
          mode: :strict
        )
      end

      it 'allows later with_context calls to override earlier ones' do
        query.with_context(foo: 1).with_context(foo: 2).result

        expect(Oj).to have_received(:dump).with(
          hash_including(
            context: hash_including(foo: 2)
          ),
          mode: :strict
        )
      end

      it 'handles empty hash without error' do
        query.with_context({}).result

        expect(Oj).to have_received(:dump).with(
          hash_including(
            context: hash_including(sqlQueryId: String)
          ),
          mode: :strict
        )
      end
    end

    context 'when with_context attempts to override other with_* methods' do
      it 'built-in with_cache takes precedence over with_context' do
        query.with_cache.with_context(useCache: false).result

        expect(Oj).to have_received(:dump).with(
          hash_including(
            context: hash_including(useCache: true)
          ),
          mode: :strict
        )
      end

      it 'built-in with_approximate_count_distinct takes precedence over with_context' do
        query.with_approximate_count_distinct.with_context(useApproximateCountDistinct: false).result

        expect(Oj).to have_received(:dump).with(
          hash_including(
            context: hash_including(useApproximateCountDistinct: true)
          ),
          mode: :strict
        )
      end

      it 'built-in in_time_zone takes precedence over with_context' do
        query.in_time_zone('America/Los_Angeles').with_context(sqlTimeZone: 'UTC').result

        expect(Oj).to have_received(:dump).with(
          hash_including(
            context: hash_including(sqlTimeZone: 'America/Los_Angeles')
          ),
          mode: :strict
        )
      end

      it 'built-in with_priority takes precedence over with_context' do
        query.with_priority(10).with_context(priority: 5).result

        expect(Oj).to have_received(:dump).with(
          hash_including(
            context: hash_including(priority: 10)
          ),
          mode: :strict
        )
      end

      it 'built-in with_windowing takes precedence over with_context' do
        query.with_windowing.with_context(enableWindowing: false).result

        expect(Oj).to have_received(:dump).with(
          hash_including(
            context: hash_including(enableWindowing: true)
          ),
          mode: :strict
        )
      end
    end

    context 'when other with_* methods override with_context' do
      it 'allows with_cache to override with_context' do
        query.with_context(useCache: false).with_cache.result

        expect(Oj).to have_received(:dump).with(
          hash_including(
            context: hash_including(useCache: true)
          ),
          mode: :strict
        )
      end

      it 'allows without_cache to override with_context' do
        query.with_context(useCache: true).without_cache.result

        expect(Oj).to have_received(:dump).with(
          hash_including(
            context: hash_including(useCache: false)
          ),
          mode: :strict
        )
      end

      it 'allows with_approximate_top_n to override with_context' do
        query.with_context(useApproximateTopN: false).with_approximate_top_n.result

        expect(Oj).to have_received(:dump).with(
          hash_including(
            context: hash_including(useApproximateTopN: true)
          ),
          mode: :strict
        )
      end

      it 'allows in_time_zone to override with_context' do
        query.with_context(sqlTimeZone: 'UTC').in_time_zone('America/New_York').result

        expect(Oj).to have_received(:dump).with(
          hash_including(
            context: hash_including(sqlTimeZone: 'America/New_York')
          ),
          mode: :strict
        )
      end

      it 'allows with_priority to override with_context' do
        query.with_context(priority: 5).with_priority(10).result

        expect(Oj).to have_received(:dump).with(
          hash_including(
            context: hash_including(priority: 10)
          ),
          mode: :strict
        )
      end

      it 'allows without_windowing to override with_context' do
        query.with_context(enableWindowing: true).without_windowing.result

        expect(Oj).to have_received(:dump).with(
          hash_including(
            context: hash_including(enableWindowing: false)
          ),
          mode: :strict
        )
      end
    end

    context 'when the query was already executed' do
      it 'raises an Aganakti::QueryAlreadyExecutedError' do
        query.result

        expect { query.with_context(foo: 1) }.to raise_error(
          Aganakti::QueryAlreadyExecutedError,
          'with_context cannot be set because the query has already been executed'
        )
      end
    end

    context 'when combining with_context and other methods' do
      it "doesn't affect unrelated context parameters" do
        query.with_context(customParam: 'value').with_cache.result

        expect(Oj).to have_received(:dump).with(
          hash_including(
            context: hash_including(
              customParam: 'value',
              useCache: true
            )
          ),
          mode: :strict
        )
      end

      it 'allows complex chaining scenarios' do
        query
          .with_cache
          .with_context(customParam: 'initial')
          .with_priority(5)
          .with_context(anotherParam: 'value')
          .in_time_zone('America/Los_Angeles')
          .result

        expect(Oj).to have_received(:dump).with(
          hash_including(
            context: hash_including(
              customParam: 'initial',
              anotherParam: 'value',
              useCache: true,
              priority: 5,
              sqlTimeZone: 'America/Los_Angeles'
            )
          ),
          mode: :strict
        )
      end
    end
  end
end
