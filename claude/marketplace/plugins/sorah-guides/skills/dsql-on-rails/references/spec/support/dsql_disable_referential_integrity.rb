# frozen_string_literal: true

# DatabaseRewinder wraps each DELETE in ALTER TABLE ... DISABLE/ENABLE TRIGGER ALL.
# DSQL tables have no triggers, so those round-trips are pure overhead.
module DsqlDisableReferentialIntegrity
  def disable_referential_integrity
    yield
  end
end

ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.prepend(DsqlDisableReferentialIntegrity)
