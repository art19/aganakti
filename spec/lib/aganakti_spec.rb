# frozen_string_literal: true

RSpec.describe Aganakti do
  describe '::VERSION' do
    it { expect(described_class::VERSION).not_to be nil }
    it { expect(described_class::VERSION).to be_frozen }
  end

  describe '::Error' do
    it 'is a subclass of StandardError' do
      expect(described_class::Error).to(satisfy { |c| c < StandardError })
    end
  end

  %i[
    ConfigurationError IllegalEscapeError QueryAlreadyExecutedError QueryResultTruncatedError
    QueryResultUnparseableError QueryTimedOutError QueryError
  ].each do |err|
    describe "::#{err}" do
      it 'is a subclass of Aganakti::Error' do
        expect(described_class.const_get(err)).to(satisfy { |c| c < described_class::Error })
      end
    end
  end
end
