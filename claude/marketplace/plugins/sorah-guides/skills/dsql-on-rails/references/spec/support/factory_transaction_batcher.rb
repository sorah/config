# frozen_string_literal: true

# Opt-in with `:batch_transactions` metadata: each example runs in one transaction, so its writes
# share a single COMMIT round trip. Nested `transaction` calls join it.
#
# Not for groups that test after_commit behaviour (callbacks fire only in the after hook), nor for
# code that manages its own transactions.
#
# Hooks are LIFO and support files load alphabetically, so this file's after hook commits
# before database_rewinder's after hook cleans up.
module FactoryTransactionBatcher
  # Errors here are swallowed; the example's own result stands.
  def self.finalize_transaction(conn)
    conn.commit_transaction
  rescue StandardError
    conn.rollback_transaction rescue nil # rubocop:disable Style/RescueModifier
  end
end

RSpec.configure do |config|
  config.prepend_before do |example|
    if example.metadata[:batch_transactions]
      # _lazy (private API) defers BEGIN until the first query.
      ActiveRecord::Base.lease_connection.begin_transaction(joinable: true, _lazy: true)
    end
  end

  config.after do |example|
    next unless example.metadata[:batch_transactions]

    conn = ActiveRecord::Base.lease_connection
    FactoryTransactionBatcher.finalize_transaction(conn) if conn.transaction_open?
  end
end
