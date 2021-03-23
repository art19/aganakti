# frozen_string_literal: true

RSpec.describe Aganakti::Client do
  describe '.new' do
    it 'freezes the options'
    it 'freezes the URI'
    it 'overrides Accept header'
    it 'overrides Content-Type header'
    it 'sets up an instrumenter'
    it 'works with no options specified'
  end

  describe '#escape_identifier' do
    it "doesn't corrupt a string containing single quotes"
    it 'escapes a string containing double quotes'
    it 'passes UTF-8 characters transparently'
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
  end

  describe '#query' do
    it 'assumes your query is valid'
    it 'supports passing no parameters'
    it 'supports passing parameters'
  end
end
