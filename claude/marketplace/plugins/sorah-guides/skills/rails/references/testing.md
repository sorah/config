# Rails Testing Patterns

## `build` over `create`

A database write is the most expensive part of most examples.

- In-memory behavior (return values, attribute state, delegation): `build`.
- Database behavior (scopes, queries, uniqueness constraints): `create`.
- Delegation (`revoke!` calls `discard!`): `build` plus a spy.

```ruby
# Good
it "delegates to discard!" do
  session = FactoryBot.build(:session)
  allow(session).to receive(:discard!)

  session.revoke!

  expect(session).to have_received(:discard!)
end

it "raises when already revoked" do
  session = FactoryBot.build(:session, :revoked)

  expect { session.revoke! }.to raise_error(Discard::RecordNotDiscarded)
end

# Bad - persists a record the assertion never reads back
it "delegates to discard!" do
  session = FactoryBot.create(:session)
  session.revoke!
  expect(session).to be_discarded
end
```

## `let_it_be` (test-prof)

`let_it_be` creates a record once per example group and shares it across examples.

Use it for records that are only read, shared by several examples, and expensive to build (a user with associations). Do not use it for records an example mutates (`update!`, `destroy!`, `discard!`, `save!`), records that must differ per example, or records whose unique columns would collide.

```ruby
RSpec.describe PasswordAuthenticator do
  let_it_be(:user) { FactoryBot.create(:user) }

  # Some examples discard it, so it is a plain let.
  let(:password_credential) { FactoryBot.create(:password_credential, user:) }

  context "with a revoked credential" do
    before { password_credential.discard! }
    # ...
  end
end
```

Where transactional rollback between examples is unavailable (a database without `SAVEPOINT`, see /sorah-guides:dsql-on-rails), a mutation to a `let_it_be` record leaks into every later example in the group, so the read-only rule is a correctness rule, not a style one.

## Post-commit side effects

A spec helper that wraps each example in one transaction (to batch commits, or transactional fixtures) defers `after_commit` callbacks and `enqueue_after_transaction_commit` until that transaction ends, after the example body. An example asserting `have_enqueued_job` on an after-commit enqueue then fails. Take that example group out of the wrapper; never set `enqueue_after_transaction_commit = false` on the job.

## OpenAPI contract tests (openapi_first)

When the API has an OpenAPI document, request specs validate both request and response against it. Include the helpers once:

```ruby
# spec/support/openapi_first.rb
OpenapiFirst::Test.setup do |config|
  config.register(Rails.root.join("openapi.yml"))
end

RSpec.configure do |config|
  config.include OpenapiFirst::Test::Methods, type: :request
end
```

Replace bare status checks with `assert_api_conform(status:)` for any path, method and status the document defines, including error statuses:

```ruby
post "/v1/sessions", params: {login: "user@test.invalid"}, as: :json
assert_api_conform(status: 401)
```

Keep `expect(response).to have_http_status(...)` where the document has no matching response (a framework-level 404 before routing reaches a controller) or the route is not in the document.

## Profiling

```bash
FPROF=1 bundle exec rspec                          # factory usage
EVENT_PROF=sql.active_record bundle exec rspec     # time in SQL
EVENT_PROF=factory.create bundle exec rspec        # time in factory creates
bundle exec rspec --profile 20                     # slowest examples
```

Use these for the ad hoc statement counts quoted in a PR instead of query-count assertions.

## References

- [test-prof](https://test-prof.evilmartians.io/), [let_it_be](https://test-prof.evilmartians.io/recipes/let_it_be)
- [openapi_first](https://github.com/ahx/openapi_first)
