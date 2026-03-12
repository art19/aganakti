# frozen_string_literal: true

module Aganakti
  class Query
    ##
    # Provides methods for parsing a query result response. Called by
    # {Aganakti::Query}; you should not use this directly.
    #
    # @private
    class ResultParser
      class << self
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

        ##
        # Validates the Typhoeus response to determine if we should continue parsing it
        #
        # @param resp [Typhoeus::Response] the response
        # @raise [Aganakti::QueryError] if either a cURL error occurred or the server was unable to handle the query
        # @raise [Aganakti::QueryTimedOutError] if the query timed out before being able to be executed
        def validate_response!(resp)
          resp_code = resp.code
          return if resp_code == 200 # this is intentionally not .success? because all other status codes are unexpected

          raise QueryTimedOutError if resp.timed_out?
          raise QueryError, "cURL error #{Ethon::Curl.easy_codes.index(resp.return_code)}: #{resp.return_message}" if resp_code.zero?

          error_msg = parse_query_error(resp.body)
          raise QueryCancelledError, error_msg if query_cancelled?(resp.body)

          raise QueryError, error_msg
        end

        private

        ##
        # Given a response body, parse an error message from it
        #
        # @param body [String] the response body with errors inside
        # @return [String] the error message
        def parse_query_error(body)
          begin
            error_info = Oj.load(body, mode: :strict)

            error_msg_components = [error_info['error'], error_info['errorMessage']].compact
            error_msg = error_msg_components.join(': ') unless error_msg_components.empty?
          rescue Oj::ParseError
            nil
          ensure
            error_msg ||= "An error occurred, but the server's response was unparseable: #{body}"
          end

          error_msg
        end

        ##
        # Determines if the error response indicates the query was cancelled
        #
        # @param body [String] the response body
        # @return [Boolean] true if the query was cancelled
        def query_cancelled?(body)
          error_info = Oj.load(body, mode: :strict)
          error_class = error_info['errorClass'].to_s
          error_msg   = error_info['errorMessage'].to_s

          error_class.include?('QueryInterruptedException') || error_msg.include?('Cancel') || error_msg.include?('cancel')
        rescue Oj::ParseError
          false
        end
      end
    end
    private_constant :ResultParser
  end
end
