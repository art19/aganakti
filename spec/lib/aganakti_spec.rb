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

  describe '.new' do
    context 'with an invalid URI' do
      pending
    end

    context 'with a FTP URI' do
      pending
    end

    context 'with a HTTP URI' do
      pending
    end

    context 'with a HTTPS URI' do
      pending
    end

    context 'with a specified but missing CA bundle' do
      pending
    end

    context 'with a specified but unreadable CA bundle' do
      pending
    end

    context "with a specified CA bundle but it's a directory" do
      pending
    end

    context 'with a specified CA bundle that is correct' do
      pending
    end

    context 'with a specified user agent prefix' do
      pending
    end

    context 'with credentials specified in a HTTP URI but without setting the :insecure_plaintext_login option' do
      pending
    end

    context 'with credentials specified in a HTTP URI and setting the :insecure_plaintext_login option' do
      pending
    end
  end
end
