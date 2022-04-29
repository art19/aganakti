# frozen_string_literal: true

RSpec.shared_context 'with a stubbed Aganakti::Client', :stubbed_client do
  before do
    allow(Aganakti::Client).to receive(:new).with(instance_of(String), instance_of(Hash)).once
  end
end

RSpec.shared_context 'with a stubbed request and response', :stubbed_request do
  subject(:query) { Aganakti::Query.new(client, 'SELECT 1', []) }

  let(:client)           { instance_double(Aganakti::Client, instrumenter: instrumenter, typhoeus_options: typhoeus_options, uri: uri) }
  let(:instrumenter)     { instance_double(ActiveSupport::Notifications::Instrumenter) }
  let(:result)           { instance_double(ActiveRecord::Result) }
  let(:request)          { instance_double(Typhoeus::Request) }
  let(:response)         { instance_double(Typhoeus::Response) }
  let(:typhoeus_options) { { headers: { 'Accept' => 'application/json', 'Content-Type' => 'application/json' } } }
  let(:uri)              { 'http://localhost' }

  before do
    allow(Aganakti::Query.const_get(:ResultParser)).to receive(:parse_response).and_return(result)
    allow(Aganakti::Query.const_get(:ResultParser)).to receive(:validate_response!)
    allow(Typhoeus::Request).to receive(:new).and_return(request)
    allow(instrumenter).to receive(:instrument).and_yield
    allow(request).to receive(:run).and_return(response)
  end
end
