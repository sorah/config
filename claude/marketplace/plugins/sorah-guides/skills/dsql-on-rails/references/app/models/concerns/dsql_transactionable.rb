# frozen_string_literal: true

# OCC-aware transactions for DSQL, included in ApplicationRecord. DSQL rejects a conflicting
# transaction at commit instead of waiting on a lock, so idempotent blocks are retried.
module DsqlTransactionable
  extend ActiveSupport::Concern

  module ClassMethods
    def retryable_transaction(retries: 4, base_sleep_seconds: 0.2, &block)
      attempts = 0

      begin
        transaction(&block)
      rescue ActiveRecord::SerializationFailure => e
        if e.dsql_retryable? && attempts < retries
          attempts += 1
          sleep_time = base_sleep_seconds * (2**(attempts - 1)) * (0.5 + (0.5 * rand))
          Rails.logger.warn("DSQL conflict detected, retrying transaction (#{attempts}/#{retries}), waiting #{format("%.2f", sleep_time)}s: #{e.message}")
          sleep(sleep_time)
          retry
        else
          raise
        end
      end
    end

    # Marks a transaction that must not be retried (external side effects, data read before the block).
    def non_idempotent_transaction(&block)
      transaction(&block)
    end
  end

  def retryable_transaction(...) = self.class.retryable_transaction(...)
  def non_idempotent_transaction(&block) = self.class.non_idempotent_transaction(&block)
end
