# frozen_string_literal: true

module Aganakti
  class Query
    ##
    # Mixes in methods to build a query. Called by {Aganakti::Query}; you should not
    # need to use this directly.
    #
    # @api private
    module Building
      protected

      ##
      # Builds the query context that's included in the query payload.
      #
      # @return [Hash] the query context
      def query_context
        {
          sqlQueryId: @qid,
          sqlTimeZone: @time_zone,
          useApproximateCountDistinct: @approximate_count_distinct,
          useApproximateTopN: @approximate_top_n
        }.compact!.freeze
      end

      ##
      # Builds the query parameters that's included in the query payload.
      #
      # @return [Array<Hash>] query parameters
      def query_parameters # rubocop:disable Metrics/CyclomaticComplexity, Metrics/MethodLength
        @params.map do |param|
          case param
          when BigDecimal then { type: 'DECIMAL', value: param.to_s('F') }
          when Date       then { type: 'DATE', value: param.strftime('%F') }
          when DateTime   then { type: 'TIMESTAMP', value: param.to_time.utc.strftime('%F %T.%N') }
          when Float      then { type: 'DOUBLE', value: param.to_s }
          when Integer    then { type: 'INTEGER', value: param.to_s }
          when Time       then { type: 'TIMESTAMP', value: param.utc.strftime('%F %T.%N') }
          else                 { type: 'VARCHAR', value: param.to_s }
          end
        end.freeze
      end

      ##
      # Builds the query payload, prior to converting it to JSON.
      #
      # @return [Hash] the query payload
      def query_payload
        {
          query: @sql,
          header: true,
          parameters: query_parameters,
          resultFormat: 'arrayLines', # This avoids repeating the column names every row
          context: query_context
        }.compact!.freeze
      end
    end
  end
end
