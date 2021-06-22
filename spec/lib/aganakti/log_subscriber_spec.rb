# frozen_string_literal: true

RSpec.describe Aganakti::LogSubscriber do
  before do
    allow(ActiveSupport::LogSubscriber).to receive(:colorize_logging).and_return(true)
    allow(ActiveSupport::LogSubscriber).to receive(:logger).and_return(logger)
  end

  context 'with a logger that has debugging enabled' do
    let(:logger) { instance_double(Logger) }

    before do
      allow(logger).to receive(:debug?).and_return(true)
      allow(logger).to receive(:debug)
    end

    context 'without binds or flags' do
      before do
        ActiveSupport::Notifications.instrumenter.instrument(
          'sql.aganakti',
          name:          'Druid SQL',
          sql:           'bogus',
          binds:         [],
          connection:    nil,
          query_context: {}
        ) do
          # don't do anything; Rails 5.x requires a block to be passed
        end
      end

      it 'checked the log level of the logger' do
        expect(logger).to have_received(:debug?)
      end

      it 'logged the expected message' do
        expect(logger).to have_received(:debug).with(/
          \A                           # match at start of text
          \x20\x20                     # line must start with two spaces
          \e\[1m                       # bold
          \e\[35m                      # magenta
          Druid\x20SQL\x20\(\d\.\dms\) # source and timing information
          \e\[0m                       # reset
          \x20\x20                     # two spaces before SQL
          \e\[1m                       # bold
          \e\[34m                      # blue
          bogus                        # SQL
          \e\[0m                       # reset
          \z                           # match at end of text
        /x)
      end
    end

    context 'with binds' do
      before do
        ActiveSupport::Notifications.instrumenter.instrument(
          'sql.aganakti',
          name:          'Druid SQL',
          sql:           'bogus',
          binds:         [1, '2', 3.45, BigDecimal('6.7'), true],
          connection:    nil,
          query_context: {}
        ) do
          # don't do anything; Rails 5.x requires a block to be passed
        end
      end

      it 'checked the log level of the logger' do
        expect(logger).to have_received(:debug?)
      end

      it 'logged the expected message' do # rubocop:disable RSpec/ExampleLength
        expect(logger).to have_received(:debug).with(/
          \A                           # match at start of text
          \x20\x20                     # line must start with two spaces
          \e\[1m                       # bold
          \e\[35m                      # magenta
          Druid\x20SQL\x20\(\d\.\dms\) # source and timing information
          \e\[0m                       # reset
          \x20\x20                     # two spaces before SQL
          \e\[1m                       # bold
          \e\[34m                      # blue
          bogus                        # SQL
          \e\[0m                       # reset
          \x20\x20                     # two spaces
          \[                           # the binds array
            1,\x20
            "2",\x20
            3\.45,\x20
            0\.67e1,\x20
            true
          \]
          \z                           # match at end of text
        /x)
      end
    end

    context 'with flags set to an unexpected value' do
      before do
        ActiveSupport::Notifications.instrumenter.instrument(
          'sql.aganakti',
          name:          'Druid SQL',
          sql:           'bogus',
          binds:         [],
          connection:    nil,
          query_context: {
            useApproximateTopN: 'test'
          }
        ) do
          # don't do anything; Rails 5.x requires a block to be passed
        end
      end

      it 'checked the log level of the logger' do
        expect(logger).to have_received(:debug?)
      end

      it 'logged the expected message' do # rubocop:disable RSpec/ExampleLength
        expect(logger).to have_received(:debug).with(/
          \A                           # match at start of text
          \x20\x20                     # line must start with two spaces
          \e\[1m                       # bold
          \e\[35m                      # magenta
          Druid\x20SQL\x20\(\d\.\dms\) # source and timing information
          \e\[0m                       # reset
          \x20\x20                     # two spaces before SQL
          \e\[1m                       # bold
          \e\[34m                      # blue
          bogus                        # SQL
          \e\[0m                       # reset
          \e\[1m                       # bold
          \e\[36m                      # cyan
          \x20\x20                     # two spaces before flags
          \(                           # flags
            approximate\x20top\x20N\x20=\x20"test"
          \)
          \e\[0m                       # reset
          \z                           # match at end of text
        /x)
      end
    end

    context 'with one flag' do
      before do
        ActiveSupport::Notifications.instrumenter.instrument(
          'sql.aganakti',
          name:          'Druid SQL',
          sql:           'bogus',
          binds:         [],
          connection:    nil,
          query_context: {
            sqlTimeZone: 'Foo/Bar'
          }
        ) do
          # don't do anything; Rails 5.x requires a block to be passed
        end
      end

      it 'checked the log level of the logger' do
        expect(logger).to have_received(:debug?)
      end

      it 'logged the expected message' do # rubocop:disable RSpec/ExampleLength
        expect(logger).to have_received(:debug).with(%r{
          \A                           # match at start of text
          \x20\x20                     # line must start with two spaces
          \e\[1m                       # bold
          \e\[35m                      # magenta
          Druid\x20SQL\x20\(\d\.\dms\) # source and timing information
          \e\[0m                       # reset
          \x20\x20                     # two spaces before SQL
          \e\[1m                       # bold
          \e\[34m                      # blue
          bogus                        # SQL
          \e\[0m                       # reset
          \e\[1m                       # bold
          \e\[36m                      # cyan
          \x20\x20                     # two spaces before flags
          \(                           # flags
            in\x20time\x20zone\x20Foo/Bar
          \)
          \e\[0m                       # reset
          \z                           # match at end of text
        }x)
      end
    end

    context 'with two flags' do
      before do
        ActiveSupport::Notifications.instrumenter.instrument(
          'sql.aganakti',
          name:          'Druid SQL',
          sql:           'bogus',
          binds:         [],
          connection:    nil,
          query_context: {
            useApproximateCountDistinct: true,
            useApproximateTopN:          false
          }
        ) do
          # don't do anything; Rails 5.x requires a block to be passed
        end
      end

      it 'checked the log level of the logger' do
        expect(logger).to have_received(:debug?)
      end

      it 'logged the expected message' do # rubocop:disable RSpec/ExampleLength
        expect(logger).to have_received(:debug).with(/
          \A                           # match at start of text
          \x20\x20                     # line must start with two spaces
          \e\[1m                       # bold
          \e\[35m                      # magenta
          Druid\x20SQL\x20\(\d\.\dms\) # source and timing information
          \e\[0m                       # reset
          \x20\x20                     # two spaces before SQL
          \e\[1m                       # bold
          \e\[34m                      # blue
          bogus                        # SQL
          \e\[0m                       # reset
          \e\[1m                       # bold
          \e\[36m                      # cyan
          \x20\x20                     # two spaces before flags
          \(                           # flags
            with\x20approximate\x20count\x20distinct,\x20
            without\x20approximate\x20top\x20N
          \)
          \e\[0m                       # reset
          \z                           # match at end of text
        /x)
      end
    end

    context 'with everything turned on' do
      before do
        ActiveSupport::Notifications.instrumenter.instrument(
          'sql.aganakti',
          name:          'Druid SQL',
          sql:           'bogus',
          binds:         ['bind'],
          connection:    nil,
          query_context: {
            sqlTimeZone:                 'Foo/Bar',
            useApproximateCountDistinct: true,
            useApproximateTopN:          false
          }
        ) do
          # don't do anything; Rails 5.x requires a block to be passed
        end
      end

      it 'checked the log level of the logger' do
        expect(logger).to have_received(:debug?)
      end

      it 'logged the expected message' do # rubocop:disable RSpec/ExampleLength
        expect(logger).to have_received(:debug).with(%r{
          \A                           # match at start of text
          \x20\x20                     # line must start with two spaces
          \e\[1m                       # bold
          \e\[35m                      # magenta
          Druid\x20SQL\x20\(\d\.\dms\) # source and timing information
          \e\[0m                       # reset
          \x20\x20                     # two spaces before SQL
          \e\[1m                       # bold
          \e\[34m                      # blue
          bogus                        # SQL
          \e\[0m                       # reset
          \e\[1m                       # bold
          \e\[36m                      # cyan
          \x20\x20                     # two spaces before flags
          \(                           # flags
            in\x20time\x20zone\x20Foo/Bar,\x20
            with\x20approximate\x20count\x20distinct,\x20
            without\x20approximate\x20top\x20N
          \)
          \e\[0m                       # reset
          \x20\x20                     # two spaces
          \[                           # binds
            "bind"
          \]
          \z                           # match at end of text
        }x)
      end
    end
  end

  context 'with a logger that does not have debugging enabled' do
    let(:logger) { instance_double(Logger) }

    before do
      allow(logger).to receive(:debug?).and_return(false)
      allow(logger).to receive(:debug)

      ActiveSupport::Notifications.instrumenter.instrument(
        'sql.aganakti',
        name:          'Druid SQL',
        sql:           'bogus',
        binds:         [],
        connection:    nil,
        query_context: {}
      ) do
        # don't do anything; Rails 5.x requires a block to be passed
      end
    end

    it 'checked the log level of the logger' do
      expect(logger).to have_received(:debug?)
    end

    it "didn't log anything" do
      expect(logger).not_to have_received(:debug)
    end
  end
end
