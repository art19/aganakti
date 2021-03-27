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

  describe '#add_value' do
    context 'when called before receiving an array start' do
      pending
    end

    context 'when called after receiving an array end' do
      pending
    end

    context 'when called after receiving an array start but before receiving an array end' do
      pending
    end

    context 'when called with a key' do
      pending
    end
  end

  describe '#array_end' do
    context 'when called after array_start and without a key' do
      it 'freezes the row' do
        parser.array_start(nil)

        expect { parser.array_end(nil) }.to change { parser.row.frozen? }.from(false).to(true)
      end
    end

    context 'when called after it was already called' do
      it 'raises Aganakti::QueryResultUnparseableError' do
        parser.array_start(nil)
        parser.array_end(nil)

        expect { parser.array_end(nil) }.to raise_error(Aganakti::QueryResultUnparseableError, 'Row was already finished')
      end
    end

    context 'when called before array_start was called' do
      it 'raises Aganakti::QueryResultUnparseableError' do
        expect { parser.array_end(nil) }.to raise_error(Aganakti::QueryResultUnparseableError, 'Row was already finished')
      end
    end

    context 'when called with a key' do
      it 'always raises Aganakti::QueryResultUnparseableError' do
        expect { parser.array_end('boom') }.to raise_error(Aganakti::QueryResultUnparseableError, 'Encountered unexpected key for an array')
      end
    end
  end

  describe '#array_start' do
    context 'when called after it was already called' do
      it 'raises Aganakti::QueryResultUnparseableError' do
        parser.array_start(nil)

        expect { parser.array_start(nil) }.to raise_error(Aganakti::QueryResultUnparseableError, 'Row was already initialized')
      end
    end

    context 'when called without a key and without already being called' do
      it 'initializes the row' do
        expect { parser.array_start(nil) }.to change(parser, :row).from(nil).to([])
      end
    end

    context 'when called with a key' do
      it 'always raises Aganakti::QueryResultUnparseableError' do
        expect { parser.array_start('boom') }.to raise_error(Aganakti::QueryResultUnparseableError, 'Encountered unexpected key for an array')
      end
    end
  end

  describe '#hash_end' do
    it 'always raises Aganakti::QueryResultUnparseableError' do
      expect { parser.hash_end(nil) }.to raise_error(Aganakti::QueryResultUnparseableError, 'Encountered unexpected } in response')
    end
  end

  describe '#hash_start' do
    it 'always raises Aganakti::QueryResultUnparseableError' do
      expect { parser.hash_start(nil) }.to raise_error(Aganakti::QueryResultUnparseableError, 'Encountered unexpected { in response')
    end
  end

  describe '#parse' do
    context 'with invalid JSON' do
      let(:doc) do
        '} [ funny: 0, { json: -1 } ]'
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

    context 'with two otherwise valid JSON documents' do
      let(:doc) do
        <<~DOC
          ["a nice", "happy", "row", 13.12, true, 1.2345e6, 5432]
          ["a nice", "happy", "row", 13.12, true, 9.8765e6, 321]
        DOC
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
