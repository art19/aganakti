# frozen_string_literal: true

# All of the methods tested are protected, which is ordinarily not a good idea to test,
# but these are protected simply to hide them from the public API, and testing their
# functionality within {Aganakti::Query} is a pain.
RSpec.describe 'Aganakti::Query::Building' do # NB: using a string here because it's a private constant
  let(:described_class) { Aganakti::Query.const_get(:Building) }

  let(:dummy_instance) do
    Object.new.tap do |inst|
      inst.extend(described_class)
    end
  end

  it 'is a private constant' do
    expect { Aganakti::Query::Building }.to raise_error(NameError, /private constant .* referenced/)
  end

  describe '::SQL_TIME_FORMAT' do
    it 'is a private constant' do
      expect { described_class::SQL_TIME_FORMAT }.to raise_error(NameError, /private constant .* referenced/)
    end

    it 'is frozen' do
      expect(described_class.const_get(:SQL_TIME_FORMAT)).to be_frozen
    end

    it 'is the correct format' do
      expect(described_class.const_get(:SQL_TIME_FORMAT)).to eq('%F %T.%N%z')
    end
  end

  describe '#query_context' do
    let(:query_context) { dummy_instance.send(:query_context) }

    it 'has a sqlQueryId key' do
      uuid = SecureRandom.uuid
      dummy_instance.instance_variable_set(:@qid, uuid)

      expect(query_context).to eq(sqlQueryId: uuid)
    end

    it 'has a sqlTimeZone key' do
      dummy_instance.instance_variable_set(:@time_zone, 'Foo/Bar')

      expect(query_context).to eq(sqlTimeZone: 'Foo/Bar')
    end

    it 'has a useApproximateCountDistinct key' do
      dummy_instance.instance_variable_set(:@approximate_count_distinct, true)

      expect(query_context).to eq(useApproximateCountDistinct: true)
    end

    it 'has a useApproximateTopN key' do
      dummy_instance.instance_variable_set(:@approximate_top_n, false)

      expect(query_context).to eq(useApproximateTopN: false)
    end

    it 'is empty when all the options are nil' do
      expect(query_context).to eq({})
    end

    it 'is frozen' do
      expect(query_context).to be_frozen
    end
  end

  describe '#query_parameters' do
    let(:query_parameters) { dummy_instance.send(:query_parameters) }

    context 'with more than one parameter' do
      it 'supports multiple parameters' do
        dummy_instance.instance_variable_set(:@params, %w[a b c])

        expect(query_parameters).to eq([
                                         { type: 'VARCHAR', value: 'a' },
                                         { type: 'VARCHAR', value: 'b' },
                                         { type: 'VARCHAR', value: 'c' }
                                       ])
      end
    end

    context 'with one parameter' do
      it 'handles BigDecimal' do
        dummy_instance.instance_variable_set(:@params, [BigDecimal('1.2345')])

        expect(query_parameters).to eq([{ type: 'DECIMAL', value: '1.2345' }])
      end

      it 'handles Date' do
        dummy_instance.instance_variable_set(:@params, [Date.new(2021, 3, 31)])

        expect(query_parameters).to eq([{ type: 'DATE', value: '2021-03-31' }])
      end

      it 'handles DateTime' do
        dummy_instance.instance_variable_set(:@params, [DateTime.new(2021, 3, 31, 16, 39, 12.3456)])

        expect(query_parameters).to eq([{ type: 'TIMESTAMP', value: '2021-03-31 16:39:12.345600000+0000' }])
      end

      it 'handles FalseClass' do
        dummy_instance.instance_variable_set(:@params, [false])

        expect(query_parameters).to eq([{ type: 'BOOLEAN', value: false }])
      end

      it 'handles Float' do
        dummy_instance.instance_variable_set(:@params, [13.12])

        expect(query_parameters).to eq([{ type: 'DOUBLE', value: 13.12 }])
      end

      it 'handles Integer' do
        dummy_instance.instance_variable_set(:@params, [1312])

        expect(query_parameters).to eq([{ type: 'INTEGER', value: 1312 }])
      end

      it 'handles String (UTF-8)' do
        dummy_instance.instance_variable_set(:@params, ['🧇'])

        expect(query_parameters).to eq([{ type: 'VARCHAR', value: '🧇' }])
      end

      it 'handles String (ISO-8859-1)' do
        dummy_instance.instance_variable_set(:@params, [String.new("\xDEink", encoding: Encoding::ISO_8859_1)])

        expect(query_parameters).to eq([{ type: 'VARCHAR', value: 'Þink'.encode(Encoding::ISO_8859_1) }])
      end

      it 'handles Time' do
        dummy_instance.instance_variable_set(:@params, [Time.at(946_684_800, 123_456_789, :nsec)])

        expect(query_parameters).to eq([{ type: 'TIMESTAMP', value: '2000-01-01 00:00:00.123456789+0000' }])
      end

      it 'handles Time in a different time zone' do
        dummy_instance.instance_variable_set(:@params, [Time.at(946_684_800, 123_456_789, :nsec, in: '+09:00')])

        expect(query_parameters).to eq([{ type: 'TIMESTAMP', value: '2000-01-01 00:00:00.123456789+0000' }])
      end

      it 'handles TrueClass' do
        dummy_instance.instance_variable_set(:@params, [true])

        expect(query_parameters).to eq([{ type: 'BOOLEAN', value: true }])
      end
    end
  end

  describe '#query_payload' do
    let(:query_payload) { dummy_instance.send(:query_payload) }

    before do
      # We don't care about the params in this spec but they can't be nil
      dummy_instance.instance_variable_set(:@params, ['y'])
    end

    it 'has a context key' do
      dummy_instance.instance_variable_set(:@time_zone, 'Foo/Bar')

      expect(query_payload).to include(context: { sqlTimeZone: 'Foo/Bar' })
    end

    it 'has a header key and it is set to true' do
      expect(query_payload).to include(header: true)
    end

    it 'has a parameters key' do
      expect(query_payload).to include(parameters: [{ type: 'VARCHAR', value: 'y' }])
    end

    it 'has a query key' do
      dummy_instance.instance_variable_set(:@sql, 'SELECT 1312')

      expect(query_payload).to include(query: 'SELECT 1312')
    end

    it 'has a resultFormat key and it is set to "arrayLines"' do
      expect(query_payload).to include(resultFormat: 'arrayLines')
    end
  end
end
