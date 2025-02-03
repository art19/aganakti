# frozen_string_literal: true

module Aganakti
  class Query
    ##
    # Mixes in methods to build a query. Called by {Aganakti::Query}; you should not
    # use this directly.
    #
    # @private
    module Building
      # The SQL time format
      SQL_TIME_FORMAT = '%F %T.%N%z'
      private_constant :SQL_TIME_FORMAT

      protected

      ##
      # Builds the query context that's included in the query payload.
      #
      # @return [Hash] the query context
      def query_context
        {
          enableWindowing:             @windowing,
          priority:                    @priority,
          sqlQueryId:                  @qid,
          sqlTimeZone:                 @time_zone,
          useApproximateCountDistinct: @approximate_count_distinct,
          useApproximateTopN:          @approximate_top_n,
          useCache:                    @cache
        }.compact.freeze
      end

      ##
      # Builds the query parameters that's included in the query payload.
      #
      # @return [Array<Hash>] query parameters in Druid's expected syntax
      # @note Druid uses SQL-format timestamps, not ISO8601 timestamps!
      def query_parameters # rubocop:disable Metrics/CyclomaticComplexity, Metrics/MethodLength
        @params.map do |param|
          # FIXME: this case statement could instead become a set of refinements that allow us to go
          #        +@params.map(&:to_druid_parameter)+, which might be cleaner
          case param
          when BigDecimal  then { type: 'DECIMAL', value: param.to_s('F') }
          when DateTime    then { type: 'TIMESTAMP', value: param.to_time.utc.strftime(SQL_TIME_FORMAT) }
          when Date        then { type: 'DATE', value: param.strftime('%F') }
          when Float       then { type: 'DOUBLE', value: param }
          when Integer     then { type: 'INTEGER', value: param }
          when Time        then { type: 'TIMESTAMP', value: param.utc.strftime(SQL_TIME_FORMAT) }
          when true, false then { type: 'BOOLEAN', value: param }
          else                  { type: 'VARCHAR', value: param.to_s }
          end
        end.freeze
      end

      ##
      # Builds the query payload, prior to converting it to JSON.
      #
      # @return [Hash] the query payload
      def query_payload
        {
          query:        @sql,
          header:       true,
          parameters:   query_parameters,
          resultFormat: 'arrayLines', # This avoids repeating the column names every row
          context:      query_context
        }.compact.freeze
      end
    end
    private_constant :Building
  end
end
