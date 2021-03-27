# frozen_string_literal: true

RSpec.describe 'Aganakti::Query::RowParser' do # NB: using a string here because it's a private constant
  subject(:parser) { described_class.new }

  let!(:described_class) { Aganakti::Query.const_get(:RowParser) }

  describe '.parse' do
    before do
      allow(Oj).to receive(:saj_parse)
    end

    it 'creates a new instance and attempts to #parse the passed document' do
      described_class.parse('[]')

      expect(Oj).to have_received(:saj_parse).with(an_instance_of(described_class), '[]')
    end
  end


  describe '#parse' do
    context 'with invalid JSON' do
      let(:doc) do
        '[ funny: 0, { json: -1 } ]'
      end

      it 'has nothing in #row' do
        parser.parse(doc)
      rescue StandardError
        nil
      ensure
        expect(parser.row).to be_nil
      end

      it 'raises an Oj::ParseError' do
        expect { parser.parse(doc) }.to raise_error(Oj::ParseError, /invalid format/)
      end
    end

    context 'with JSON in the proper format' do
      let(:doc) do
        '["a nice", "happy", "row", 13.12, true, 1.2345e6, 5432]'
      end

      let(:expectation) do
        ['a nice', 'happy', 'row', 13.12, true, 1_234_500.0, 5432]
      end

      it 'has the expected data in #row' do
        parser.parse(doc)

        expect(parser.row).to eql(expectation)
      end

      it 'returns the expected data' do
        expect(parser.parse(doc)).to eql(expectation)
      end

      it 'parses without error' do
        expect { parser.parse(doc) }.not_to raise_error
      end
    end

    context 'with JSON having unexpected internal arrays' do
      let(:doc) do
        '[["oops"], "this had an internal array", ["this is not acceptable"]]'
      end

      it 'has nothing in #row' do
        parser.parse(doc)
      rescue StandardError
        nil
      ensure
        expect(parser.row).to be_nil
      end

      it 'raises an Aganakti::QueryResultUnparseableError' do
        expect { parser.parse(doc) }.to raise_error(Aganakti::QueryResultUnparseableError, 'Row was already initialized')
      end
    end

    context 'with JSON having unexpected internal hashes' do
      let(:doc) do
        '[{"what": "how would this get returned?"}, "weird"]'
      end

      it 'has nothing in #row' do
        parser.parse(doc)
      rescue StandardError
        nil
      ensure
        expect(parser.row).to be_nil
      end

      it 'raises an Aganakti::QueryResultUnparseableError' do
        expect { parser.parse(doc) }.to raise_error(Aganakti::QueryResultUnparseableError, 'Encountered unexpected { in response')
      end
    end

    context 'with JSON having unexpected root hash' do
      let(:doc) do
        '{"this": "is not remotely correct"}'
      end

      it 'has nothing in #row' do
        parser.parse(doc)
      rescue StandardError
        nil
      ensure
        expect(parser.row).to be_nil
      end

      it 'raises an Aganakti::QueryResultUnparseableError' do
        expect { parser.parse(doc) }.to raise_error(Aganakti::QueryResultUnparseableError, 'Encountered unexpected { in response')
      end
    end

    context 'with XML' do
      let(:doc) do
        '<error>Java got confused and returned some XML, hope that was OK</error>'
      end

      it 'has nothing in #row' do
        parser.parse(doc)
      rescue StandardError
        nil
      ensure
        expect(parser.row).to be_nil
      end

      it 'raises an Oj::ParseError' do
        expect { parser.parse(doc) }.to raise_error(Oj::ParseError, /invalid format/)
      end
    end
  end
end
