# frozen_string_literal: true

RSpec.describe Aganakti::Client do
  describe '.new' do
    it 'freezes the options' do
      options = {}

      expect { described_class.new('http://localhost', options) }.to change { options.frozen? }.from(false).to(true)
    end

    it 'freezes the URI' do
      uri = String.new('http://localhost')

      expect { described_class.new(uri, {}) }.to change { uri.frozen? }.from(false).to(true)
    end

    it 'overrides Accept header' do
      client = described_class.new('http://localhost', headers: { 'Accept' => 'text/xml' })

      expect(client.typhoeus_options[:headers]).to include('Accept' => 'application/json')
    end

    it 'overrides Content-Type header' do
      client = described_class.new('http://localhost', headers: { 'Content-Type' => 'text/xml' })

      expect(client.typhoeus_options[:headers]).to include('Content-Type' => 'application/json')
    end

    it 'sets up an instrumenter' do
      client = described_class.new('http://localhost', {})

      expect(client.instrumenter).to be_an_instance_of(ActiveSupport::Notifications::Instrumenter)
    end

    it 'works with no options specified' do
      expect { described_class.new('http://localhost', {}) }.not_to raise_error
    end
  end

  describe '#escape_identifier' do
    subject(:client) { described_class.new('http://localhost', {}) }

    it "doesn't corrupt a string containing single quotes" do
      expect(client.escape_identifier("it's thinking")).to eq("it's thinking")
    end

    it 'escapes a string containing double quotes' do
      expect(client.escape_identifier('they said "a column name with double quotes is weird"'))
        .to eq('they said ""a column name with double quotes is weird""')
    end

    it 'passes UTF-8 characters transparently' do
      expect(client.escape_identifier('🍔')).to eq('🍔')
    end

    it 'returns frozen strings' do
      expect(client.escape_identifier('foo')).to be_frozen
    end
  end

  describe '#escape_literal' do
    subject(:client) { described_class.new('http://localhost', {}) }

    it "doesn't corrupt a string containing double quotes" do
      expect(client.escape_literal('this is a "test"')).to eq('this is a "test"')
    end

    it 'escapes a string containing single quotes' do
      expect(client.escape_literal("it's thinking")).to eq("it''s thinking")
    end

    it 'passes UTF-8 characters transparently' do
      expect(client.escape_literal('ᏗᏟᎶᏍᏙᏗ')).to eq('ᏗᏟᎶᏍᏙᏗ')
    end

    it 'returns frozen strings' do
      expect(client.escape_literal('foo')).to be_frozen
    end
  end

  describe '#escape_literal_unicode' do
    subject(:client) { described_class.new('http://localhost', {}) }

    it "doesn't corrupt a string containing double quotes" do
      expect(client.escape_literal_unicode('this is a "test"')).to eq('this is a "test"')
    end

    it "doesn't encode characters U+0000 to U+007F" do
      expect(client.escape_literal_unicode('test #~')).to eq('test #~')
    end

    it 'escapes a string containing acceptable Unicode' do
      expect(client.escape_literal_unicode('ᏗᏟᎶᏍᏙᏗ means sample')).to eq('\\13D7\\13DF\\13B6\\13CD\\13D9\\13D7 means sample')
    end

    it 'escapes a string containing single quotes' do
      expect(client.escape_literal_unicode("it's thinking")).to eq("it''s thinking")
    end

    it "explodes if the passed string isn't UTF-8" do
      expect { client.escape_literal_unicode(String.new('test').force_encoding(Encoding::BINARY)) }
        .to raise_error(Aganakti::IllegalEscapeError, 'passed string must be UTF-8')
    end

    it 'explodes when encoding a character outside the Unicode Basic Multilingual Plane' do
      expect { client.escape_literal_unicode('ᎠᏍᏛᎭᏟ means 🥪') }
        .to raise_error(Aganakti::IllegalEscapeError, 'Druid only supports escaping characters in the Unicode Basic Multilingual Plane (U+0000 to U+FFFF)')
    end

    it 'returns frozen strings' do
      expect(client.escape_literal_unicode('foo')).to be_frozen
    end
  end

  describe '#query' do
    subject(:client) { described_class.new('http://localhost', {}) }

    before do
      allow(Aganakti::Query).to receive(:new).once
    end

    it 'assumes your query is valid' do
      client.query('not a query')

      expect(Aganakti::Query).to have_received(:new).with(client, 'not a query', []).once
    end

    it 'supports passing no parameters' do
      client.query('SELECT foo FROM datasource')

      expect(Aganakti::Query).to have_received(:new).with(client, 'SELECT foo FROM datasource', []).once
    end

    it 'supports passing parameters' do
      client.query('SELECT foo FROM datasource WHERE bar = ? AND baz = ?', 42, 'Testing')

      expect(Aganakti::Query).to have_received(:new).with(client, 'SELECT foo FROM datasource WHERE bar = ? AND baz = ?', [42, 'Testing'])
    end
  end
end
