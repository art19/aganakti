# frozen_string_literal: true

module Aganakti
  ##
  # An instance of a Druid SQL client. Because Typhoeus/libcurl handle all thread and process safety issues, it is not necessary to create a
  # new client per thread/process (e.g., in a Unicorn after_fork). The client is intended to be constructed by Aganakti.new, which abstracts
  # some of the more complicated cURL options. You're welcome to construct this class instead if you need to do something special.
  class Client
    # TODO
  end
end
