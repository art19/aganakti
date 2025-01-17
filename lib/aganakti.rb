# frozen_string_literal: true

require 'active_support/deprecation'
require 'active_record/result'

require 'active_record/gem_version'
require 'active_support/core_ext/module/delegation'
require 'active_support/log_subscriber'
require 'active_support/notifications'
require 'concurrent/utility/monotonic_time'
require 'oj'
require 'securerandom'
require 'typhoeus'
require 'uri'

require_relative 'aganakti/client'
require_relative 'aganakti/log_subscriber'
require_relative 'aganakti/query/building'
require_relative 'aganakti/query/delegations'
require_relative 'aganakti/query/result_parser'
require_relative 'aganakti/query/row_parser'
require_relative 'aganakti/query'
require_relative 'aganakti/version'

##
# Aganakti is a client for Apache Druid SQL. See README.md for basic usage information.
module Aganakti
  ##
  # The base class for all errors raised by this library
  class Error < StandardError; end

  ##
  # There is something wrong with the configuration
  class ConfigurationError < Error; end

  ##
  # We cannot escape the requested string
  class IllegalEscapeError < Error; end

  ##
  # A query has already executed, but an operation was attempted which can only be
  # performed before the query executes.
  class QueryAlreadyExecutedError < Error; end

  ##
  # The query was not able to retrieve the entire response body
  class QueryResultTruncatedError < Error; end

  ##
  # The query result was not able to be parsed
  class QueryResultUnparseableError < Error; end

  ##
  # The HTTP request timed out while attempting to execute the query
  class QueryTimedOutError < Error; end

  ##
  # The server or client reported an error executing the query
  class QueryError < Error; end

  ##
  # Creates a new client instance.
  #
  # @param uri [String] the URI of the Druid SQL service, including username and password if applicable
  # @param options [Hash] options for the client, if needed
  # @option options [Integer] :connect_timeout (300)
  #   How many seconds to wait for a connection to be established to the server, 0 means 300 seconds
  # @option options [Boolean] :insecure_plaintext_login (false)
  #   Set to true to permit credentials to be passed with http:// URIs
  # @option options [Integer] :timeout (0)
  #   How many seconds to wait for a response from the server after connecting, 0 means wait forever
  # @option options [String] :tls_ca_certificate_bundle
  #   An optional path to the TLS CA certificate bundle to use with this connection. Your system may
  #   have such a bundle at +/etc/ssl/certs/ca-certificates.crt+, if your Druid server uses a certificate
  #   signed by a public authority.
  # @option options [String] :user_agent_prefix
  #   An optional prefix to add to the user agent, like <tt>your-app/1.0 (+http://example.com/)</tt>
  # @return [Aganakti::Client] a client that is ready for querying
  # @raise [URI::InvalidURIError] if the supplied URI can't be parsed
  # @raise [ConfigurationError] if the supplied options or URI aren't correct
  def new(uri, options = {}) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
    # I've disabled the complexity cops because this validation stuff is straightforward, but a bit verbose.

    # Check the URI for validity
    URI.parse(uri).tap do |parsed|
      raise ConfigurationError, 'URI must be a HTTP or HTTPS URI' unless parsed.is_a?(URI::HTTP) # NB: URI::HTTPS is a subclass of URI::HTTP

      if !parsed.userinfo.nil? && parsed.scheme == 'http' && !options[:insecure_plaintext_login]
        # this is verbose because I really don't want someone to accidentally expose their data without being super explicit
        raise ConfigurationError, 'Credentials cannot be provided in a HTTP URI without setting the insecure_plaintext_login option. ' \
                                  'Beware that setting this option exposes your credentials to anyone on the network and should not ' \
                                  'be used outside of development.'
      end
    end

    # Check if the CA bundle is valid
    options[:tls_ca_certificate_bundle].tap do |ca_bundle|
      unless ca_bundle.nil?
        raise ConfigurationError, "TLS CA certificate bundle file at #{ca_bundle} is missing" unless File.exist?(ca_bundle)
        raise ConfigurationError, "TLS CA certificate bundle file at #{ca_bundle} is not readable by this user" unless File.readable?(ca_bundle)
        raise ConfigurationError, "TLS CA certificate bundle file at #{ca_bundle} is a directory, but should be a file/symlink" if File.directory?(ca_bundle)
      end
    end

    # Build the user agent. Presumably you run the Druid server, so the extra information is for your benefit
    user_agent = [
      options[:user_agent_prefix],
      "Aganakti/#{Aganakti::VERSION}",
      "Typhoeus/#{Typhoeus::VERSION}",
      "Ruby/#{RUBY_VERSION}",
      Ethon::Curl.version
    ].compact.join(' ')

    # Form the options for Aganakti::Client to pass to Typhoeus
    client_options = {
      accept_encoding: '', # allow libcurl to determine its supported compression
      headers:         {
        'Connection' => 'keep-alive',
        'User-Agent' => user_agent
      },
      tcp_keeppalive:  true
    }

    client_options[:connecttimeout] = options[:connect_timeout] if options.key?(:connect_timeout)
    client_options[:cainfo] = options[:tls_ca_certificate_bundle] if options.key?(:tls_ca_certificate_bundle)
    client_options[:timeout] = options[:timeout] if options.key?(:timeout)

    # Finally construct our client
    Client.new uri, **client_options
  end
  module_function :new
end
