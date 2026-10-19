# frozen_string_literal: true

# Disables PostgreSQL adapter features DSQL does not support, and adds OCC helpers.
# Based on https://github.com/aws-samples/aurora-dsql-samples/blob/main/ruby/rails/petclinic/config/initializers/adapter.rb
# rubocop:disable Style/ClassAndModuleChildren
require "active_record/connection_adapters/postgresql/schema_statements"
module ActiveRecord::ConnectionAdapters::PostgreSQL::SchemaStatements
  def client_min_messages=(level); level; end
end

require "active_record/connection_adapters/postgresql_adapter"
class ActiveRecord::ConnectionAdapters::PostgreSQLAdapter
  def set_standard_conforming_strings = nil
  def supports_ddl_transactions? = false

  # DSQL ends the transaction itself on OC000/OC001; a ROLLBACK then only makes libpq warn
  # "there is no transaction in progress". Remove once https://github.com/rails/rails/pull/56717 ships.
  def exec_rollback_db_transaction
    return if @raw_connection.nil? || @raw_connection.transaction_status == PG::PQTRANS_IDLE

    cancel_any_running_query
    internal_execute("ROLLBACK", "TRANSACTION", allow_retry: false, materialize_transactions: true)
  end
end

require "active_record/errors"
class ActiveRecord::SerializationFailure
  # https://docs.aws.amazon.com/aurora-dsql/latest/userguide/working-with-concurrency-control.html
  def dsql_retryable?
    message.include?("(OC001)") || message.include?("(OC000)")
  end
end

# Raised untranslated when SQL goes through the raw PG connection (e.g. database_rewinder).
class PG::TRSerializationFailure
  def dsql_retryable?
    message.include?("(OC001)") || message.include?("(OC000)")
  end
end
# rubocop:enable Style/ClassAndModuleChildren
