# frozen_string_literal: true

require 'stub_server'

RSpec.describe Aganakti::Query do
  def with_stub_server(replies)
    StubServer.open(0, replies) do |server|
      server.wait

      yield server.instance_variable_get(:@server)[:Port]
    end
  end

  shared_context 'with a stubbed request', :stubbed do
    subject(:query) { described_class.new(client, 'SELECT 1', []) }

    let(:client)           { instance_double(Aganakti::Client, instrumenter: instrumenter, typhoeus_options: typhoeus_options, uri: uri) }
    let(:instrumenter)     { instance_double(ActiveSupport::Notifications::Instrumenter) }
    let(:result)           { instance_double(ActiveRecord::Result) }
    let(:request)          { instance_double(Typhoeus::Request) }
    let(:response)         { instance_double(Typhoeus::Response) }
    let(:typhoeus_options) { { headers: { 'Accept' => 'application/json', 'Content-Type' => 'application/json' } } }
    let(:uri)              { 'http://localhost' }

    before do
      allow(Aganakti::Query::ResultParser).to receive(:parse_response).and_return(result)
      allow(Aganakti::Query::ResultParser).to receive(:validate_response!)
      allow(Typhoeus::Request).to receive(:new).and_return(request)
      allow(instrumenter).to receive(:instrument).and_yield
      allow(request).to receive(:run).and_return(response)
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

  describe '.new' do
    pending
  end

  describe '#executed?', :stubbed do
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

  describe '#in_time_zone' do
    pending
  end

  describe '#includes_column?', :stubbed do
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

  describe '#with_approximate_count_distinct', :stubbed do
    before do
      allow(Oj).to receive(:dump).and_call_original.once
    end

    context 'when specified' do
      it "doesn't interact with other flags" do
        query.with_approximate_count_distinct.in_time_zone('Foo/Bar').without_approximate_top_n.result

        expect(Oj).to have_received(:dump).with(
          hash_including(
            context: hash_including(
              sqlTimeZone:        'Foo/Bar',
              useApproximateTopN: false
            )
          ),
          mode: :strict
        )
      end

      it 'sets useApproximateCountDistinct to true in the query context' do
        query.with_approximate_count_distinct.result

        expect(Oj).to have_received(:dump).with(
          hash_including(
            context: hash_including(
              useApproximateCountDistinct: true
            )
          ),
          mode: :strict
        )
      end
    end

    context 'when not specified' do
      it "doesn't interact with other flags" do
        query.in_time_zone('Foo/Bar').without_approximate_top_n.result

        expect(Oj).to have_received(:dump).with(
          hash_including(
            context: hash_including(
              sqlTimeZone:        'Foo/Bar',
              useApproximateTopN: false
            )
          ),
          mode: :strict
        )
      end

      it "doesn't set useApproximateCountDistinct in the query context" do
        query.result

        expect(Oj).to have_received(:dump).with(
          hash_including(
            context: hash_excluding(:useApproximateCountDistinct)
          ),
          mode: :strict
        )
      end
    end
  end

  describe '#with_approximate_top_n', :stubbed do
    before do
      allow(Oj).to receive(:dump).and_call_original.once
    end

    context 'when specified' do
      it "doesn't interact with other flags" do
        query.with_approximate_top_n.in_time_zone('Foo/Bar').without_approximate_count_distinct.result

        expect(Oj).to have_received(:dump).with(
          hash_including(
            context: hash_including(
              sqlTimeZone:                 'Foo/Bar',
              useApproximateCountDistinct: false
            )
          ),
          mode: :strict
        )
      end

      it 'sets useApproximateTopN to true in the query context' do
        query.with_approximate_top_n.result

        expect(Oj).to have_received(:dump).with(
          hash_including(
            context: hash_including(
              useApproximateTopN: true
            )
          ),
          mode: :strict
        )
      end
    end

    context 'when not specified' do
      it "doesn't interact with other flags" do
        query.in_time_zone('Foo/Bar').without_approximate_count_distinct.result

        expect(Oj).to have_received(:dump).with(
          hash_including(
            context: hash_including(
              sqlTimeZone:                 'Foo/Bar',
              useApproximateCountDistinct: false
            )
          ),
          mode: :strict
        )
      end

      it "doesn't set useApproximateTopN in the query context" do
        query.result

        expect(Oj).to have_received(:dump).with(
          hash_including(
            context: hash_excluding(:useApproximateTopN)
          ),
          mode: :strict
        )
      end
    end
  end

  describe '#without_approximate_count_distinct', :stubbed do
    before do
      allow(Oj).to receive(:dump).and_call_original.once
    end

    context 'when specified' do
      it "doesn't interact with other flags" do
        query.without_approximate_count_distinct.in_time_zone('Foo/Bar').with_approximate_top_n.result

        expect(Oj).to have_received(:dump).with(
          hash_including(
            context: hash_including(
              sqlTimeZone:        'Foo/Bar',
              useApproximateTopN: true
            )
          ),
          mode: :strict
        )
      end

      it 'sets useApproximateCountDistinct to false in the query context' do
        query.without_approximate_count_distinct.result

        expect(Oj).to have_received(:dump).with(
          hash_including(
            context: hash_including(
              useApproximateCountDistinct: false
            )
          ),
          mode: :strict
        )
      end
    end

    context 'when not specified' do
      it "doesn't interact with other flags" do
        query.in_time_zone('Foo/Bar').without_approximate_top_n.result

        expect(Oj).to have_received(:dump).with(
          hash_including(
            context: hash_including(
              sqlTimeZone:        'Foo/Bar',
              useApproximateTopN: false
            )
          ),
          mode: :strict
        )
      end

      it "doesn't set useApproximateCountDistinct in the query context" do
        query.result

        expect(Oj).to have_received(:dump).with(
          hash_including(
            context: hash_excluding(:useApproximateCountDistinct)
          ),
          mode: :strict
        )
      end
    end
  end

  describe '#without_approximate_top_n', :stubbed do
    before do
      allow(Oj).to receive(:dump).and_call_original.once
    end

    context 'when specified' do
      it "doesn't interact with other flags" do
        query.without_approximate_top_n.in_time_zone('Foo/Bar').with_approximate_count_distinct.result

        expect(Oj).to have_received(:dump).with(
          hash_including(
            context: hash_including(
              sqlTimeZone:                 'Foo/Bar',
              useApproximateCountDistinct: true
            )
          ),
          mode: :strict
        )
      end

      it 'sets useApproximateTopN to false in the query context' do
        query.without_approximate_top_n.result

        expect(Oj).to have_received(:dump).with(
          hash_including(
            context: hash_including(
              useApproximateTopN: false
            )
          ),
          mode: :strict
        )
      end
    end

    context 'when not specified' do
      it "doesn't interact with other flags" do
        query.in_time_zone('Foo/Bar').without_approximate_count_distinct.result

        expect(Oj).to have_received(:dump).with(
          hash_including(
            context: hash_including(
              sqlTimeZone:                 'Foo/Bar',
              useApproximateCountDistinct: false
            )
          ),
          mode: :strict
        )
      end

      it "doesn't set useApproximateTopN in the query context" do
        query.result

        expect(Oj).to have_received(:dump).with(
          hash_including(
            context: hash_excluding(:useApproximateTopN)
          ),
          mode: :strict
        )
      end
    end
  end

  %w[[] columns column_types each last length map empty? rows to_ary to_a].each do |del|
    describe "##{del}", :stubbed do
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
end
