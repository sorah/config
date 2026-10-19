# frozen_string_literal: true

require "database_rewinder"
require "database_rewinder/cleaner"
require "database_rewinder/active_record_monkey"

RSpec.configure do |config|
  config.before(:suite) do
    DatabaseRewinder.init
    # Without a pool, clean_all falls back to ActiveRecord::Base.connection, which raises
    # under `permanent_connection_checkout = :disallowed`.
    DatabaseRewinder.cleaners.each { |c| c.pool ||= ActiveRecord::Base.connection_pool }
    DsqlRetryable.with_retry("before(:suite) DatabaseRewinder.clean_all") { DatabaseRewinder.clean_all }

    # The railtie's on_load hook can run before the adapter class is loaded.
    adapter = ActiveRecord::Base.with_connection(&:class)
    unless adapter < DatabaseRewinder::InsertRecorder
      adapter.prepend(DatabaseRewinder::InsertRecorder)
    end
  end

  # Track tables inserted in before(:all) hooks (including let_it_be)
  # Capture tables at the START of the first test (after all before(:all) hooks have run)
  # and store them to exclude from cleanup.
  #
  # Note on nested example groups: If you have nested describe/context blocks where both
  # parent and child use let_it_be, the child group's first example will capture tables
  # from both parent and child before(:all) hooks. Child group's let_it_be records will
  # persist across child examples and won't be cleaned until the parent's after(:all).
  # This is the intended behavior - nested let_it_be records follow the same lifecycle
  # as their enclosing example group.
  config.prepend_before do |example|
    # Only capture on the first example in the group
    unless example.example_group.metadata[:_before_all_tables_captured]
      tables = DatabaseRewinder.cleaners.flat_map(&:inserted_tables).uniq
      example.example_group.metadata[:_before_all_inserted_tables] = tables
      example.example_group.metadata[:_before_all_tables_captured] = true
    end

    # Remove before_all tables from tracking so they won't be cleaned after each test.
    # Use subtraction and replace instead of reject! to avoid mutation issues if tests
    # insert into the same tables as before_all hooks.
    before_all_tables = example.example_group.metadata[:_before_all_inserted_tables] || []
    if before_all_tables.any?
      DatabaseRewinder.cleaners.each do |c|
        c.inserted_tables.replace(c.inserted_tables - before_all_tables)
      end
    end
  end

  config.after do
    DsqlRetryable.with_retry("after DatabaseRewinder.clean") { DatabaseRewinder.clean }
  end

  config.after(:all) do
    DsqlRetryable.with_retry("after(:all) DatabaseRewinder.clean_all") { DatabaseRewinder.clean_all }
  end
end
