# frozen_string_literal: true

require 'active_support/deprecation'
require 'active_record/result'
require 'oj'

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
          return if resp.code == 200 # this is intentionally not .success? because all other status codes are unexpected

          raise QueryTimedOutError if resp.timed_out?
          raise QueryError, "cURL error #{Ethon::Curl.easy_codes.index(resp.return_code)}: #{resp.return_message}" if resp.code.zero?

          raise QueryError, parse_query_error(resp.body)
        end

        private

        ##
        # Given a response body, parse an error message from it
        #
        # @param body [String] the response body with errors inside
        # @return [String] the error message
        def parse_query_error(body)
          error_msg = nil

          begin
            error_info = Oj.load(body, mode: :strict)

            error_msg_components = [error_info['error'], error_info['errorMessage']].compact
            error_msg = error_msg_components.join(': ') unless error_msg_components.empty?
          ensure
            error_msg ||= "An error occurred, but the server's response was unparseable: #{body}"
          end

          error_msg
        end
      end
    end
    private_constant :ResultParser
  end
end
