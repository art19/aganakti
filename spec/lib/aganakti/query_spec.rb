# frozen_string_literal: true

RSpec.describe Aganakti::Query do
  let(:client)           { instance_double(Aganakti::Client, instrumenter: instrumenter, typhoeus_options: typhoeus_options, uri: uri) }
  let(:instrumenter)     { instance_double(ActiveSupport::Notifications::Instrumenter) }
  let(:result)           { instance_double(ActiveRecord::Result) }
  let(:request)          { instance_double(Typhoeus::Request) }
  let(:response)         { instance_double(Typhoeus::Response) }
  let(:typhoeus_options) { { headers: { 'Accept' => 'application/json', 'Content-Type' => 'application/json' } } }
  let(:uri)              { 'http://localhost' }

  before do
    allow(instrumenter).to receive(:instrument).and_yield
    allow(request).to receive(:run).and_return(response)
  end

  describe '::BOOL_SETTING_METHODS' do
    it 'cannot be accessed normally because it is a private constant' do
      expect { described_class::BOOL_SETTING_METHODS }.to raise_error(NameError, /private constant .*BOOL_SETTING_METHODS referenced/)
    end

    it 'is frozen if we access the private constant anyways' do
      expect(described_class.const_get(:BOOL_SETTING_METHODS)).to be_frozen
    end
  end

  describe '.new'

  describe '#executed?' do
    context 'with a query that #result has been called on' do
      it 'returns true'
    end

    context 'with a query that #result has never been called on' do
      it 'returns false'
    end
  end

  describe '#in_time_zone'

  describe '#result' do
    context 'when calling once' do
      it "doesn't mark the query as executed when there is an error"
      it 'executes the query'
      it 'handles execution errors'
      it 'handles query timeouts'
      it 'handles truncated responses'
      it 'parses query results correctly'
    end

    context 'when calling more than once' do
      it 'executes the query once and returns cached results otherwise'
    end
  end

  describe '#with_approximate_count_distinct' do
    context 'when specified' do
      it "doesn't interact with other flags"
      it 'sets useApproximateCountDistinct to true in the query context'
    end

    context 'when not specified' do
      it "doesn't interact with other flags"
      it "doesn't set useApproximateCountDistinct in the query context"
    end
  end

  describe '#with_approximate_top_n'

  describe '#without_approximate_count_distinct'

  describe '#without_approximate_top_n'

  %w[[] columns column_types each includes_column? last length map empty? rows to_ary to_a].each do |del|
    describe "##{del}" do
      subject(:query) { described_class.new(client, 'SELECT 1', []) }

      before do
        allow(Aganakti::Query::ResultParser).to receive(:parse_response).and_return(result)
        allow(Aganakti::Query::ResultParser).to receive(:validate_response!)
        allow(Typhoeus::Request).to receive(:new).and_return(request)
        allow(result).to receive(del.to_sym)
      end

      it "delegates to result##{del}" do
        if ['[]', 'includes_column?'].include?(del)
          query.public_send(del.to_sym, 'dummy')
        else
          query.public_send(del.to_sym)
        end

        expect(result).to have_received(del.to_sym)
      end

      it 'is properly identified as existing via #respond_to?' do
        expect(query.respond_to?(del.to_sym)).to be(true)
      end
    end
  end
end
