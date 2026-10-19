# frozen_string_literal: true

require "test_prof"
require "test_prof/recipes/rspec/let_it_be"

# The default adapter wraps before_all in a SAVEPOINT, which DSQL lacks; DatabaseRewinder cleans up instead.
# A let_it_be record is one shared row and Ruby object for the whole group: mutations, and association
# caches filled by creating children, leak into later examples. Use `reload: true` or `refind: true` then.
TestProf::BeforeAll.adapter = TestProf::BeforeAll::NoopAdapter

TestProf::EventProf.configure do |config|
  config.per_example = true
end
