# frozen_string_literal: true

module Aganakti
  class Query
    ##
    # This is a streaming row parser that grabs only what we support from the response and raises
    # {Aganakti::QueryResultUnparseableError} whenever something happens that we don't handle.
    #
    # When parsing is complete, the row will be in the frozen array available at {#row}.
    #
    # This is called by {Aganakti::Query}; you should not need to use this directly.
    #
    # @example
    #   require 'oj'
    #
    #   Oj.saj_parse(RowParser.new, json_data)
    #
    # @example
    #   RowParser.parse(json_data)
    #
    # @private
    class RowParser < ::Oj::Saj
      ##
      # @return [Array<String>] The contents of the row
      attr_reader :row

      class << self
        ##
        # Constructs a new parser and calls {#parse} on it with the argument.
        #
        # @param line (see #parse)
        # @return (see #parse)
        # @raise (see #parse)
        def parse(line)
          new.parse(line)
        end
      end

      ##
      # Takes a string containing a JSON line and parses it using this parser
      #
      # @param line [String] a JSON line
      # @return [Array<String>] the parsed row
      # @raise [Aganakti::QueryResultUnparseableError] if the line couldn't be parsed
      # @raise [Oj::ParseError] if the line couldn't be parsed at an even lower level
      def parse(line)
        ::Oj.saj_parse(self, line)

        row || []
      rescue StandardError => e
        # On error, reset the row
        @row = nil

        raise e
      end

      # @!group Saj Parser Callbacks

      ##
      # Not to be called directly. Used by the Saj parser to add a value detected.
      #
      # @api private
      # @param value [String] the value to add
      # @param key [*] the key, if this weren't an array
      # @raise [Aganakti::QueryResultUnparseableError]
      #   if we encounter a value before the array was initialized, or the array is frozen
      def add_value(value, key)
        raise QueryResultUnparseableError, 'Encountered unexpected key for a value' unless key.nil?
        raise QueryResultUnparseableError, 'Encountered value before array start' if @row.nil?
        raise QueryResultUnparseableError, 'Row was already finished' if @row.frozen?

        @row << value
      end

      ##
      # Not to be called directly. Used by the Saj parser to begin an array. The row array
      # will be initialized here.
      #
      # @api private
      # @param key [*] the key, if this weren't an array at the root
      # @raise [Aganakti::QueryResultUnparseableError] if the row was already initialized or there is a key
      def array_start(key)
        raise QueryResultUnparseableError, 'Encountered unexpected key for an array' unless key.nil?
        raise QueryResultUnparseableError, 'Row was already initialized' unless @row.nil?

        @row = []
      end

      ##
      # Not to be called directly. Used by the Saj parser to end an array. The row array
      # will be frozen here and no more items can be added to it.
      #
      # @api private
      # @param key [*] the key, if this weren't an array at the root
      # @raise [Aganakti::QueryResultUnparseableError] if there is a key or the row was already frozen
      def array_end(key)
        raise QueryResultUnparseableError, 'Encountered unexpected key for an array' unless key.nil?
        raise QueryResultUnparseableError, 'Row was already finished' if @row.frozen?

        @row.freeze
      end

      ##
      # Not to be called directly. Used by the Saj parser to start a hash. This should never
      # happen, so this method always raises.
      #
      # @api private
      # @param _key [*] the key of the hash
      # @raise [Aganakti::QueryResultUnparseableError] always, this should never be called by the parser
      def hash_start(_key)
        raise QueryResultUnparseableError, 'Encountered unexpected { in response'
      end

      ##
      # Not to be called directly. Used by the Saj parser to end a hash. This should never
      # happen, so this method always raises.
      #
      # @api private
      # @param _key [*] the key of the hash
      # @raise [Aganakti::QueryResultUnparseableError] always, this should never be called by the parser
      def hash_end(_key)
        raise QueryResultUnparseableError, 'Encountered unexpected } in response'
      end

      # @!endgroup
    end
    private_constant :RowParser
  end
end
