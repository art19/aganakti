# frozen_string_literal: true

require 'active_record/gem_version'
require 'active_support/core_ext/module/delegation'

module Aganakti
  class Query
    ##
    # Mixes in delegations so the query quacks like an +ActiveRecord::Result+
    #
    # @see https://api.rubyonrails.org/classes/ActiveRecord/Result.html ActiveRecord::Result
    module Delegations
      ##
      # @!macro [attach] activerecord_result_delegator
      #   @!method $1
      #     Delegates to <tt>$2.$1</tt>
      #
      #     @see ActiveRecord::Result#$1
      delegate '[]', to: :result
      delegate :columns, to: :result
      delegate :column_types, to: :result
      delegate :each, to: :result
      delegate :last, to: :result
      delegate :length, to: :result
      delegate :map, to: :result
      delegate :empty?, to: :result
      delegate :rows, to: :result
      delegate :to_ary, to: :result
      delegate :to_a, to: :result

      # :nocov:
      delegate :includes_column?, to: :result if ActiveRecord::VERSION::MAJOR >= 6
      # :nocov:
    end
  end
end
