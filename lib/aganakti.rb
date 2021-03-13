# frozen_string_literal: true

require_relative 'aganakti/client'
require_relative 'aganakti/version'

##
# Aganakti is a client for Apache Druid SQL. See README.md for basic usage information.
module Aganakti
  ##
  # The base class for all errors raised by this library
  class Error < StandardError; end

  ##
  # Creates a new client instance.
  #
  # @param uri [String] the URI of the Druid SQL service, including username and password if applicable
  # @param options [Hash] options for the client, if needed
  # @option options [String] :tls_ca_certificate_bundle An optional path to the TLS CA certificate
  #                                                     bundle to use with this connection
  # @option options [String] :user_agent_prefix An optional prefix to add to the user agent, like
  #                                             <tt>your-app/1.0 (+http://example.com/)</tt>
  def new(uri, options = {})
    # TODO
  end
end
