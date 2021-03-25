# frozen_string_literal: true

RSpec.describe Aganakti do
  describe '::VERSION' do
    it { expect(described_class::VERSION).not_to be nil }
    it { expect(described_class::VERSION).to be_frozen }
  end
end
