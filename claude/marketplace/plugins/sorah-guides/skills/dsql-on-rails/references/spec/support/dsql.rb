# frozen_string_literal: true

module DsqlTestHelper
  # Model for DSQL conflict testing (internal to this helper)
  class TestDsqlConflict < ApplicationRecord
    self.table_name = "test_dsql_conflicts"
    self.primary_key = "id"
  end

  # Makes the enclosing transaction fail with OC001 at commit: another connection
  # updates a row this transaction has read and is about to update.
  def trigger_dsql_conflict!
    # Create record using separate thread/connection so it's immediately committed
    record_id = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        TestDsqlConflict.create!.id
      end
    end.value

    victim_ready = Queue.new

    winner_thread = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        victim_ready.pop # Wait for victim to read the record
        r = TestDsqlConflict.find(record_id)
        r.update!(counter: r.counter + 100)
      end
    end

    r = TestDsqlConflict.find(record_id)   # Read to establish snapshot
    victim_ready.push(true)                # Signal victim has read
    winner_thread.value                    # Wait for winner to commit (re-raises on error)
    r.update!(counter: r.counter + 1)      # This conflicts with winner
  end
end

module DsqlRetryable
  BASE_SLEEP_SECONDS = 0.1
  MAX_RETRIES = 10

  def self.sleep_duration(attempt)
    BASE_SLEEP_SECONDS * (2**(attempt - 1))
  end

  def self.with_retry(label)
    retries = 0
    begin
      yield
    rescue ActiveRecord::SerializationFailure, PG::TRSerializationFailure => e
      raise unless e.dsql_retryable? && retries < MAX_RETRIES

      retries += 1
      warn "retryable SerializationFailure in #{label}, retrying (#{retries}/#{MAX_RETRIES})"
      sleep sleep_duration(retries)
      retry
    end
  end

  # A MultipleExceptionError (e.g. test body + after hook) is retryable only when every error in it is.
  def self.retryable_exception?(exception)
    case exception
    when ActiveRecord::SerializationFailure, PG::TRSerializationFailure
      exception.dsql_retryable?
    when RSpec::Core::MultipleExceptionError
      exception.all_exceptions.all? { |e| retryable_exception?(e) }
    when RSpec::Expectations::ExpectationNotMetError
      # OCC errors caught by raise_error / not_to raise_error matchers surface as
      # ExpectationNotMetError with OCC details in the message, e.g.:
      #   expected SomeError, got #<ActiveRecord::SerializationFailure:"...OC001...">
      exception.message.include?("(OC001)") || exception.message.include?("(OC000)")
    else
      false
    end
  end
end

module DsqlBeforeAllRetry
  def before_all(setup_fixtures: TestProf::BeforeAll.config.setup_fixtures, &block)
    return super(setup_fixtures: setup_fixtures) unless block

    retryable_block = proc {
      retries = 0
      begin
        # One COMMIT per let_it_be block instead of one per record; each COMMIT is a network round trip.
        ActiveRecord::Base.transaction { instance_exec(&block) } # rubocop:disable Dsql/TransactionOccAwareness
      rescue ActiveRecord::SerializationFailure, PG::TRSerializationFailure => e
        raise unless e.dsql_retryable? && retries < DsqlRetryable::MAX_RETRIES

        retries += 1
        warn "retryable SerializationFailure in before_all/let_it_be, retrying (#{retries}/#{DsqlRetryable::MAX_RETRIES})"
        sleep DsqlRetryable.sleep_duration(retries)
        retry
      end
    }
    super(setup_fixtures: setup_fixtures, &retryable_block)
  end
end

RSpec::Core::ExampleGroup.singleton_class.prepend(DsqlBeforeAllRetry)

RSpec.configure do |config|
  config.include DsqlTestHelper

  # Other work on the same cluster (DDL, async index builds) causes OCC conflicts too.
  config.around do |example|
    example.run
    10.times do |i|
      break if example.exception.nil?
      break unless DsqlRetryable.retryable_exception?(example.exception)

      warn "retryable SerializationFailure detected in #{example.location} ; retrying the test (#{i + 1}/#{DsqlRetryable::MAX_RETRIES})"
      sleep DsqlRetryable.sleep_duration(i + 1)

      # DatabaseRewinder has deleted the rows memoized let values point at.
      example.example.instance_variable_get(:@example_group_instance)&.send(:__init_memoized)

      example.example.display_exception = nil
      example.run
    end
  end
end
