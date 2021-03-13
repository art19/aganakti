# frozen_string_literal: true

module Aganakti
  ##
  # An instance of a Druid SQL client. Because Typhoeus/libcurl handle all thread and process safety issues, it is not necessary to create a
  # new client per thread/process (e.g., in a Unicorn after_fork). The client is intended to be constructed by Aganakti.new, which abstracts
  # some of the more complicated cURL options. You're welcome to construct this class instead if you need to do something special.
  class Client
    ##
    # @return [Hash] The options that are passed to Typhoeus
    attr_reader :typhoeus_options

    ##
    # @return [String] The URI to make queries against
    attr_reader :uri

    ##
    # Creates a new client instance. You probably want to use Aganakti.new unless you need to specify your own Typhoeus options.
    #
    # @param uri [String] the URI to the Druid SQL endpoint, with username/password in it
    # @param typhoeus_options [Hash] options to use with Typhoeus
    def initialize(uri, typhoeus_options)
      @typhoeus_options = typhoeus_options
      @uri              = uri
    end
  end
end
