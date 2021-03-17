# frozen_string_literal: true

require 'json'

module Aganakti
  class Query
    ##
    # Provides methods for parsing a query result response. Called by
    # {Aganakti::Query}; you should not need to use this directly.
    #
    # @api private
    module ResultParser
      ##
      # Parses the successful response body. Note that no checking is performed for the server returning
      # a different number of columns in the header vs. in the result. This shouldn't happen and would
      # be a parser issue, but the parser checks for every possibly weird situation and so this sacrifice
      # was made for performance.
      #
      # @param resp [Typhoeus::Response] the response object
      # @return [ActiveRecord::Result] the result set
      # @raise [Aganakti::QueryResultTruncatedError] if the query result is incomplete and can't be trusted
      def parse_response(resp)
        lines = resp.body.lines

        raise QueryResultTruncatedError unless lines.last == "\n"

        rows    = lines.reject { |line| line == "\n" }.map(&RowParser.method(:parse))
        columns = rows.shift

        ActiveRecord::Result.new(columns, rows.freeze)
      end
      module_function :parse_response

      ##
      # Validates the Typhoeus response to determine if we should continue parsing it
      #
      # @param resp [Typhoeus::Response] the response
      # @raise [Aganakti::QueryError] if either a cURL error occurred or the server was unable to handle the query
      # @raise [Aganakti::QueryTimedOutError] if the query timed out before being able to be executed
      def validate_response!(resp)
        raise QueryTimedOutError if resp.timed_out?
        raise QueryError, "cURL error #{resp.return_code}: #{resp.return_message}" if resp.code.zero?
        return if resp.code == 200

        begin
          error_info = JSON.parse(resp.body)
          raise QueryError, [error_info['error'], error_info['errorMessage']].compact!.join(': ')
        rescue StandardError
          raise QueryError, "An error occurred, but the server's response was unparseable"
        end
      end
      module_function :validate_response!
    end
  end
end
