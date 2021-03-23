# frozen_string_literal: true

require 'active_support/notifications'

require_relative 'query'

module Aganakti
  ##
  # An instance of a Druid SQL client. Because Typhoeus/libcurl handle all thread and process safety issues, it is not necessary to create a
  # new client per thread/process (e.g., in a Unicorn after_fork). The client is intended to be constructed by {Aganakti.new}, which abstracts
  # some of the more complicated cURL options. You're welcome to construct this class instead if you need to do something special.
  #
  # The main method on this class is {#query}, which allows you to construct an optionally parameterized query.
  #
  # This class additionally has some helpers for escaping when parameterized queries are unavailable or are unsupported in the
  # situation you're in (e.g., +INTERVAL '5' MONTHS+ cannot use a parameter for +'5'+). These methods are on the client instance rather than
  # the client class to provide for the possibility of server-specific escaping rules in the future.
  class Client
    ##
    # @api private
    # @return [ActiveSupport::Notifications::Instrumenter] the ActiveSupport::Notifications instrumenter
    attr_reader :instrumenter

    ##
    # @return [Hash] The options that are passed to Typhoeus
    attr_reader :typhoeus_options

    ##
    # @return [String] The URI to make queries against
    attr_reader :uri

    ##
    # Creates a new client instance. You probably want to use {Aganakti.new} unless you need to specify your own Typhoeus options.
    #
    # @param uri [String] The URI to the Druid SQL endpoint, with username/password in it
    # @param options [Hash] Options to use with Typhoeus
    def initialize(uri, options)
      options[:headers] ||= {}
      options[:headers]['Accept'] = 'application/json'
      options[:headers]['Content-Type'] = 'application/json'

      @instrumenter     = ActiveSupport::Notifications.instrumenter
      @typhoeus_options = options.freeze
      @uri              = uri.freeze
    end

    ##
    # Escapes an identifier like a table or column name so that it can be safely interpolated into a query. Do not use this
    # to escape literals like values in +WHERE+ clauses.
    #
    # @param str [String] the identifier you want to escape
    # @return [String] the escaped identifier
    # @see https://druid.apache.org/docs/latest/querying/sql.html#identifiers-and-literals Apache Druid: SQL: Identifiers and Literals
    def escape_identifier(str)
      str.gsub('"', '""')
    end

    ##
    # Build or perform a query against Druid.
    #
    # @param sql [String]
    #   The SQL query to execute, which can possibly contain +?+ where you want to parameterize (like Rails)
    # @param params [Array<BigDecimal, Date, DateTime, Float, Integer, String, Time>]
    #   Optional parameters for the query. The type of the parameter (BigDecimal, String, etc.) determines how it is
    #   interpreted by Druid. Beware! This library handles decimal types with care, but Druid treats decimal types as
    #   floating point, so not accounting for this may result in unexpected behavior.
    # @return [Aganakti::Query]
    #   The query instance, which can be operated on as if it were an +ActiveRecord::Result+, or additional modifiers can
    #   be added as needed.
    def query(sql, *params)
      Query.new(self, sql, params)
    end
    alias ᏥᏔᏲᎯᎭ query # rubocop:disable Naming/AsciiIdentifiers
  end
end
