# frozen_string_literal: true

module Aganakti
  ##
  # A log subscriber using the +ActiveSupport::LogSubscriber+ interface. It only logs anything if the logger
  # has debug level enabled.
  #
  # @see ActiveSupport::LogSubscriber
  # @see https://api.rubyonrails.org/classes/ActiveSupport/LogSubscriber.html ActiveSupport::LogSubscriber in the Rails docs
  class LogSubscriber < ActiveSupport::LogSubscriber
    ##
    # Called by ActiveSupport notifications when there's a SQL query that executes
    #
    # @param event [ActiveSupport::Notifications::Event] the aganakti.sql event that was triggered
    def sql(event)
      return unless logger.debug?

      payload = event.payload

      binds   = binds(payload[:binds])
      context = context_flags(payload[:query_context])
      name    = "#{payload[:name]} (#{event.duration.round(1)}ms)"
      sql     = payload[:sql]

      # Replicate the Rails scheme, but since we can only SELECT, we can simplify their logic
      debug "  #{color(name, MAGENTA, true)}  #{color(sql, BLUE, true)}#{context}#{binds}"
    end

    private

    ##
    # Given the list of binds from the payload, return how they should look in the log
    #
    # @param binds [Array<String, Integer, Float>] the binds
    # @return [String, nil] the rendered string, if there are any binds
    def binds(binds)
      binds.inspect.prepend('  ') if binds.any?
    end

    ##
    # Given the Druid query context, return a string suitable for logging that returns the query
    # flags from the query context.
    #
    # @param context [Hash] the Druid query context
    # @return [String, nil] a string containing query flags, if any
    def context_flags(context)
      flags = []

      flags << "in time zone #{context[:sqlTimeZone]}" unless context[:sqlTimeZone].nil?

      approx_count_distinct = context[:useApproximateCountDistinct]
      approx_top_n          = context[:useApproximateTopN]

      flags << with_without_context_flag('approximate count distinct', approx_count_distinct) unless approx_count_distinct.nil?
      flags << with_without_context_flag('approximate top N', approx_top_n) unless approx_top_n.nil?

      return if flags.empty?

      color("  (#{flags.join(', ')})", CYAN, true)
    end

    ##
    # Given a query context flag value and the human version of it, return the human
    # version prepended with "with " or "without ", or nil if the value isn't strictly
    # true or false.
    #
    # @param human [String] the human name of the flag
    # @param value [Boolean, nil] the value of the flag
    # @return [String, nil] the context flag with "with " or "without " prepended, or nil
    def with_without_context_flag(human, value)
      case value
      when true then  "with #{human}"
      when false then "without #{human}"
      else "#{human} = #{value.inspect}"
      end
    end
  end
end

Aganakti::LogSubscriber.attach_to :aganakti
