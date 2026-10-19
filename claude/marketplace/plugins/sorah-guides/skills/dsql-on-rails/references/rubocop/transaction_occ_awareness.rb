# frozen_string_literal: true

module RuboCop
  module Cop
    module Dsql
      # Flags #transaction and #with_lock so every transaction declares how it handles OCC conflicts.
      class TransactionOccAwareness < RuboCop::Cop::Base
        MSG = "Use #retryable_transaction or #non_idempotent_transaction for DSQL OCC awareness."

        RESTRICT_ON_SEND = %i[transaction with_lock].freeze

        def on_send(node)
          add_offense(node.loc.selector)
        end
      end
    end
  end
end
