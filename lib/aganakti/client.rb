# frozen_string_literal: true

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

    # The headers we forbid because we override them (these must be lowercase strings)
    FORBIDDEN_HEADERS = %w[accept content-type].freeze
    private_constant :FORBIDDEN_HEADERS

    # The headers we are overriding
    HEADER_OVERRIDES = {
      'Accept' => 'application/json',
      'Content-Type' => 'application/json'
    }.freeze
    private_constant :HEADER_OVERRIDES

    ##
    # Creates a new client instance. You probably want to use {Aganakti.new} unless you need to specify your own Typhoeus options.
    #
    # @param uri [String]
    #   The URI to the Druid SQL endpoint, with username/password in it.
    # @param options [Hash]
    #   Options to use with Typhoeus. The Accept and Content-Type headers will be overwritten with the correct MIME types.
    def initialize(uri, options)
      (options[:headers] ||= {}).delete_if { |key, _value| FORBIDDEN_HEADERS.include?(key.downcase) }.merge!(HEADER_OVERRIDES)

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
      str.gsub('"', '""').freeze
    end

    ##
    # Escapes a literal like a value you're searching for so that it can be safely interpolated into a query. Do not use this
    # to escape identifiers like column names or +AS "foo"+ in +SELECT+ lists. This method additionally passes Unicode transparently,
    # which may or may not work depending on how the intermediate systems like proxies process requests. {#escape_literal_unicode} can
    # be used to escape in these situations, but beware that Druid currently cannot handle escape sequences outside of the Unicode
    # Basic Multilingual Plane (e.g., U+0000 to U+FFFF).
    #
    # Where possible, it is best practice to use a parameterized query and avoid this method entirely.
    #
    # @param str [String] the literal you want to escape
    # @return [String] the escaped literal
    # @see https://druid.apache.org/docs/latest/querying/sql.html#identifiers-and-literals Apache Druid: SQL: Identifiers and Literals
    def escape_literal(str)
      str.gsub("'", "''").freeze
    end

    ##
    # Escapes a literal like a value you're searching for so that it can be safely interpolated into a query, but with Unicode
    # escaping in case intermediate systems cannot handle UTF-8. Do not use this to escape identifiers like column names or
    # +AS "foo"+ in +SELECT+ lists. If intermediate systems do support UTF-8 properly, then it would be preferable to use
    # {#escape_literal} instead as it does not limit you to the Unicode Basic Multilingual Plane (U+0000 to U+FFFF) like this
    # method does due to Druid limitations. When using a literal escaped using this method, you must prefix the literal with
    # +U&+ in your query, e.g., +U&'\13d7\13df\13b6\13cd\13d9\13d7'+.
    #
    # Where possible, it is best practice to use a parameterized query and avoid this method entirely.
    #
    # @param str [String] the literal you want to escape
    # @return [String] the escaped literal
    # @raise [Aganakti::IllegalEscapeError] if we cannot escape the string passed in
    # @see https://druid.apache.org/docs/latest/querying/sql.html#identifiers-and-literals Apache Druid: SQL: Identifiers and Literals
    def escape_literal_unicode(str) # rubocop:disable Metrics/MethodLength
      raise IllegalEscapeError, 'passed string must be UTF-8' unless str.encoding == Encoding::UTF_8

      String.new.tap do |out|
        escape_literal(str).each_codepoint do |char|
          raise IllegalEscapeError, 'Druid only supports escaping characters in the Unicode Basic Multilingual Plane (U+0000 to U+FFFF)' if char > 0xFFFF

          # characters from 0x00 to 0x7F encode 1:1 to Unicode and do not need to be escaped
          out << if char > 0x7F
                   "\\#{format('%04X', char)}"
                 else
                   char
                 end
        end
      end.freeze
    end

    ##
    # Build or perform a query against Druid.
    #
    # @param sql [String]
    #   The SQL query to execute, which can possibly contain +?+ where you want to parameterize (like Rails)
    # @param params [Array<BigDecimal, Date, DateTime, Float, Integer, String, Time>]
    #   Optional parameters for the query. The type of the parameter (BigDecimal, String, etc.) determines how it is
    #   interpreted by Druid. Beware! Druid treats decimal types as floating point, so not accounting for this may result
    #   in unexpected behavior.
    # @return [Aganakti::Query]
    #   The query instance, which can be operated on as if it were an +ActiveRecord::Result+, or additional modifiers can
    #   be added as needed.
    def query(sql, *params)
      Query.new(self, sql, params)
    end
    alias ᏥᏔᏲᎯᎭ query # rubocop:disable Naming/AsciiIdentifiers
  end
end
