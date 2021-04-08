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
      it 'raises a URI::InvalidURIError' do
        expect { described_class.new('is it pronounced hydro city zone or hydrossity zone?') }.to raise_error(URI::InvalidURIError)
      end
    end

    context 'with an FTP URI' do
      it 'raises an Aganakti::ConfigurationError' do
        expect { described_class.new('ftp://segapr.segaamerica.com/SEGA_ARCHIVES/Dreamcast_Games/Seaman/seam7.jpg') }
          .to raise_error(Aganakti::ConfigurationError, 'URI must be a HTTP or HTTPS URI')
      end
    end

    %w[HTTP HTTPS].each do |proto|
      context "with a #{proto} URI", :stubbed_client do
        let(:url) { "#{proto.downcase}://druidserver/query" }

        it 'created a client with accept_encoding = ""' do
          described_class.new(url)

          expect(Aganakti::Client).to have_received(:new).with(anything, hash_including(accept_encoding: ''))
        end

        it 'created a client with the Connection header set to "keep-alive"' do
          described_class.new(url)

          expect(Aganakti::Client).to have_received(:new).with(anything, hash_including(headers: hash_including('Connection' => 'keep-alive')))
        end

        it 'created a client with the expected URL' do
          described_class.new(url)

          expect(Aganakti::Client).to have_received(:new).with(url, anything)
        end

        it 'created a client with the User-Agent header set to the default' do
          described_class.new(url)

          expect(Aganakti::Client).to have_received(:new).with(anything, hash_including(
                                                                           headers: hash_including(
                                                                             # not matching beyond libcurl because it depends on the built libcurl
                                                                             'User-Agent' => %r{\AAganakti/[\w.]+ Typhoeus/[\w.]+ Ruby/[\w.]+ libcurl/.*}
                                                                           )
                                                                         ))
        end

        it 'created a client without cainfo' do
          described_class.new(url)

          expect(Aganakti::Client).to have_received(:new).with(anything, hash_including(cainfo: nil))
        end

        it 'created a client without connecttimeout' do
          described_class.new(url)

          expect(Aganakti::Client).to have_received(:new).with(anything, hash_including(connecttimeout: nil))
        end

        it 'created a client without timeout' do
          described_class.new(url)

          expect(Aganakti::Client).to have_received(:new).with(anything, hash_including(timeout: nil))
        end

        it "doesn't raise an error" do
          expect { described_class.new(url) }.not_to raise_error
        end
      end
    end

    context 'with a specified but missing CA bundle' do
      let(:ca_bundle) { '/tmp/cacerts.pem' }
      let(:url)       { 'https://druidserver/query' }

      before do
        allow(File).to receive(:exist?).with(ca_bundle).and_return(false)
      end

      it 'raises an Aganakti::ConfigurationError' do
        expect { described_class.new(url, tls_ca_certificate_bundle: ca_bundle) }
          .to raise_error(Aganakti::ConfigurationError, "TLS CA certificate bundle file at #{ca_bundle} is missing")
      end
    end

    context 'with a specified but unreadable CA bundle' do
      let(:ca_bundle) { '/tmp/cacerts.pem' }
      let(:url)       { 'https://druidserver/query' }

      before do
        allow(File).to receive(:exist?).with(ca_bundle).and_return(true)
        allow(File).to receive(:readable?).with(ca_bundle).and_return(false)
      end

      it 'raises an Aganakti::ConfigurationError' do
        expect { described_class.new(url, tls_ca_certificate_bundle: ca_bundle) }
          .to raise_error(Aganakti::ConfigurationError, "TLS CA certificate bundle file at #{ca_bundle} is not readable by this user")
      end
    end

    context "with a specified CA bundle but it's a directory" do
      let(:ca_bundle) { '/tmp/cacerts.pem' }
      let(:url)       { 'https://druidserver/query' }

      before do
        allow(File).to receive(:exist?).with(ca_bundle).and_return(true)
        allow(File).to receive(:readable?).with(ca_bundle).and_return(true)
        allow(File).to receive(:directory?).with(ca_bundle).and_return(true)
      end

      it 'raises an Aganakti::ConfigurationError' do
        expect { described_class.new(url, tls_ca_certificate_bundle: ca_bundle) }
          .to raise_error(Aganakti::ConfigurationError, "TLS CA certificate bundle file at #{ca_bundle} is a directory, but should be a file/symlink")
      end
    end

    context 'with a specified CA bundle that is correct', :stubbed_client do
      let(:ca_bundle) { '/tmp/cacerts.pem' }
      let(:url)       { 'https://druidserver/query' }

      before do
        allow(File).to receive(:exist?).with(ca_bundle).and_return(true)
        allow(File).to receive(:readable?).with(ca_bundle).and_return(true)
        allow(File).to receive(:directory?).with(ca_bundle).and_return(false)
      end

      it 'creates a client with cainfo' do
        described_class.new(url, tls_ca_certificate_bundle: ca_bundle)

        expect(Aganakti::Client).to have_received(:new).with(anything, hash_including(cainfo: ca_bundle))
      end

      it "doesn't raise an error" do
        expect { described_class.new(url, tls_ca_certificate_bundle: ca_bundle) }.not_to raise_error
      end
    end

    context 'with a specified connection timeout', :stubbed_client do
      let(:url) { 'https://druidserver/query' }

      it 'creates a client with connecttimeout' do
        described_class.new(url, connect_timeout: 5)

        expect(Aganakti::Client).to have_received(:new).with(anything, hash_including(connecttimeout: 5))
      end
    end

    context 'with a specified timeout', :stubbed_client do
      let(:url) { 'https://druidserver/query' }

      it 'creates a client with timeout' do
        described_class.new(url, timeout: 30)

        expect(Aganakti::Client).to have_received(:new).with(anything, hash_including(timeout: 30))
      end
    end

    context 'with a specified user agent prefix', :stubbed_client do
      let(:url) { 'https://druidserver/query' }

      it 'creates a client with the expected user agent' do
        described_class.new(url, user_agent_prefix: 'TestSuite/1')

        expect(Aganakti::Client).to have_received(:new).with(anything, hash_including(headers: hash_including('User-Agent' => %r{\ATestSuite/1 Aganakti/.*})))
      end
    end

    context 'with credentials specified in a HTTP URI but without setting the :insecure_plaintext_login option', :stubbed_client do
      let(:url) { 'http://user:pass@druidserver/query' }

      it 'raises an Aganakti::ConfigurationError' do
        expect { described_class.new(url) }
          .to raise_error(Aganakti::ConfigurationError,
                          'Credentials cannot be provided in a HTTP URI without setting the insecure_plaintext_login option. ' \
                          'Beware that setting this option exposes your credentials to anyone on the network and should not ' \
                          'be used outside of development.')
      end
    end

    context 'with credentials specified in an HTTP URI and setting the :insecure_plaintext_login option', :stubbed_client do
      let(:url) { 'http://user:pass@druidserver/query' }

      it 'creates a client with the expected URL' do
        described_class.new(url, insecure_plaintext_login: true)

        expect(Aganakti::Client).to have_received(:new).with(url, anything)
      end

      it "doesn't raise an error" do
        expect { described_class.new(url, insecure_plaintext_login: true) }.not_to raise_error
      end
    end
  end
end
