# frozen_string_literal: true

require_relative 'query/building'
require_relative 'query/delegations'
require_relative 'query/result_parser'
require_relative 'query/row_parser'

require 'oj'
require 'securerandom'
require 'typhoeus'

module Aganakti
  ##
  # This represents a Druid query. The query could already be sent, in which case, you may only fetch results.
  # If the query has not been sent, you may use the fluent interface to control Druid query context options.
  #
  # To create a query, see {Aganakti::Client#query}.
  class Query
    include Building
    include Delegations

    # The methods that are created to manage context setting booleans.
    #
    # @private
    BOOL_SETTING_METHODS = %w[
      with_approximate_count_distinct
      with_approximate_top_n
      without_approximate_count_distinct
      without_approximate_top_n
    ].freeze
    private_constant :BOOL_SETTING_METHODS

    ##
    # Creates a new Query instance. This is meant to be called by {Aganakti::Client#query}, not directly.
    #
    # @param client [Aganakti::Client] The client
    # @param sql [String] see {Aganakti::Client#query}
    # @param params [Array] see {Aganakti::Client#query}
    def initialize(client, sql, params)
      @client   = client
      @executed = false
      @sql      = sql
      @params   = params
      @qid      = SecureRandom.uuid

      # Initialize SQL context options
      @approximate_count_distinct = nil
      @approximate_top_n          = nil
      @time_zone                  = nil
    end

    ##
    # Returns if the query has been executed yet or not. If the query has executed, you
    # can no longer make configuration changes to it.
    #
    # @return [Boolean] whether the query was executed or not
    def executed?
      @executed
    end

    ##
    # Executes the query or returns the already executed result
    #
    # @return [ActiveRecord::Result] the query result
    # @raise [Aganakti::QueryError] if either a cURL error occurred or the server was unable to handle the query
    # @raise [Aganakti::QueryResultTruncatedError] if the query result is incomplete and can't be trusted
    # @raise [Aganakti::QueryResultUnparseableError] if the query result does not match the format we expect
    # @raise [Aganakti::QueryTimedOutError] if the query timed out before being able to be executed
    def result
      @result ||= begin
        payload = Oj.dump(query_payload, mode: :strict)

        resp = Typhoeus::Request.new(@client.uri, @client.typhoeus_options.merge(method: :post, body: payload)).run

        ResultParser.validate_response!(resp)
        ResultParser.parse_response(resp).tap do |_|
          @executed = true
        end
      end
    end

    # @!group Query Context Configuration Instance Methods

    ##
    # Sets the time zone for this query, which will affect how time functions and timestamp literals behave.
    # Should be a time zone name like "America/Los_Angeles" or offset like "-08:00".
    #
    # @param zone [String, nil] the timezone to configure or +nil+ to unset
    # @return [self] this instance, for chaining
    # @raise [Aganakti::QueryAlreadyExecutedError] if the query has already been executed
    def in_time_zone(zone)
      raise QueryAlreadyExecutedError, 'in_time_zone cannot be set because the query has already been executed' if executed?

      @time_zone = zone

      self
    end

    # Rather than repeat the same boilerplate over and over, use a template.
    BOOL_SETTING_METHODS.each do |setting|
      instance_eval <<-RUBY, __FILE__, __LINE__ + 1
        def #{setting}                                                               # def with_approximate_count_distinct
          if executed?                                                               #   if executed?
            raise QueryAlreadyExecutedError, "#{setting} cannot be set because " \   #     raise QueryAlreadyExecutedError, "with_approximate_count_distinct cannot be set because " \
                                            'the query has already been executed'    #                                      'the query has already been executed'
          end                                                                        #   end
                                                                                     #
          @#{setting.sub(/\A(with|without)_/, '')} = #{setting.start_with?('with_')} #   @approximate_count_distinct = true
                                                                                     #
          self                                                                       #   self
        end                                                                          # end
      RUBY
    end

    ##
    # @!method with_approximate_count_distinct
    #   Asks Druid to use an approximate cardinality algorithm for +COUNT(DISTINCT foo)+.
    #
    #   @return [self] this instance, for chaining
    #   @raise [Aganakti::QueryAlreadyExecutedError] if the query has already been executed

    ##
    # @!method with_approximate_top_n
    #   Asks Druid to use approximate TopN queries when a SQL query could be expressed
    #   as such.
    #
    #   @return [self] this instance, for chaining
    #   @raise [Aganakti::QueryAlreadyExecutedError] if the query has already been executed

    ##
    # @!method without_approximate_count_distinct
    #   Asks Druid not to use an approximate cardinality algorithm for +COUNT(DISTINCT foo)+.
    #
    #   @return [self] this instance, for chaining
    #   @raise [Aganakti::QueryAlreadyExecutedError] if the query has already been executed

    ##
    # @!method without_approximate_top_n
    #   Asks Druid not to use approximate TopN queries when a SQL query could be expressed
    #   as such. Exact GroupBy queries will be used instead.
    #
    #   @return [self] this instance, for chaining
    #   @raise [Aganakti::QueryAlreadyExecutedError] if the query has already been executed

    # @!endgroup
  end
end
