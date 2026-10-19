---
name: dsql-on-rails
description: This skill should be used when building, extending, or testing a Rails app on Amazon Aurora DSQL, or when moving a Rails app onto DSQL. Use it when writing a transaction, a uniqueness check, a schema change, a spec, a rake task, or CI for such an app, even if the user only says "add a model" or "fix this flaky spec" in such an app. Signs include `aws-sdk-dsql`, `pg-aws_rds_iam`, `aws_rds_iam_auth_token_generator`, a `*.dsql.<region>.on.aws` host, `ActiveRecord::SerializationFailure` with `OC000`/`OC001`, `retryable_transaction`, `non_idempotent_transaction`, `create index async`, `script/pdsql`, or the user mentioning "DSQL", "Aurora DSQL", or "OCC". Provides connection settings and adapter patches, OCC-aware transactions, schema constraints with psqldef, roles, per-developer schemas, RSpec setup, and CI against real clusters. Project-specific conventions always take priority.
version: 0.1.0
---

# Rails on Aurora DSQL

How to run a Rails app on Aurora DSQL, from a production setup that also runs development, tests and CI against real DSQL clusters. Project-specific conventions (CLAUDE.md, `docs/`) always take priority.

- For DSQL itself (SQL support, quotas, IAM, cluster operations), use the `/dsql` skill from AWS's [agent-plugins](https://github.com/awslabs/agent-plugins) (`databases-on-aws`).
- Schema is managed by psqldef, so read /sorah-guides:sqldef-on-rails first. This skill replaces several of its tasks.

DSQL speaks the PostgreSQL protocol but behaves differently. Plan around these:

- Optimistic concurrency control. There are no lock waits: a conflicting transaction fails at commit with `OC000`/`OC001` and has to be retried.
- No SAVEPOINT, so no nested transactions and no transactional test fixtures.
- One DDL statement per transaction. Indexes are built asynchronously (`create index async`), and DDL itself causes OCC conflicts.
- IAM authentication only. Sessions last at most one hour.
- Some changes cannot be undone later: no `ALTER COLUMN ... TYPE`, no adding `NOT NULL` to an existing column. `DROP COLUMN`, defaults, `DROP NOT NULL`, partial and expression indexes, `INCLUDE`, `NULLS NOT DISTINCT`, `json`/`jsonb`, sequences and identity columns are supported. Check `/dsql` for anything newer.
- There is no DSQL Local, so development and tests run against real clusters, and latency is what slows them down.

## Reference files

`references/` mirrors an app's tree. Copy the files, then replace the `example.com` names, the `app_<name>` role and the schema names.

| File | What it is |
|---|---|
| `config/database.yml` | Connection settings, per-developer host and schema |
| `config/initializers/dsql_monkey.rb` | Adapter patches, `dsql_retryable?` |
| `config/initializers/dsql_token.rb` | IAM token generator for `pg-aws_rds_iam`, Timecop-safe |
| `lib/dsql_host_resolver.rb` | Cluster, role and schema resolution for dev/test |
| `lib/local_config_file.rb` | `tmp/` pin files that fall back to the main checkout from a git worktree |
| `lib/tasks/database.rake` | `db:init`, `create`, `migrate`, `drop`, `pick_cluster`, `wait_for_jobs`, `wait_for_indexes`, `measure_latency`, `prune_ci`, `agent_user` |
| `script/pdsql` | psql, psqldef or any libpq tool with a fresh IAM token (`chmod +x`) |
| `app/models/concerns/dsql_transactionable.rb` | `retryable_transaction` / `non_idempotent_transaction` |
| `rubocop/transaction_occ_awareness.rb` | Cop flagging bare `transaction` / `with_lock` |
| `spec/support/*.rb`, `db/schema/test_dsql_conflicts.sql` | RSpec setup (see Tests) |

Gems: `pg`, `aws-sdk-dsql`, `pg-aws_rds_iam`; for tests `database_rewinder`, `timecop`, `test-prof`, and `parallel_tests` for CI. Put AmazonRootCA1 at `data/amazonroot.pem` (or `/etc/amazonroot.pem` in the image); without it, `sslrootcert` falls back to `system`, which needs libpq 16+. `sslnegotiation: direct` needs libpq 17+.

## Connecting

- Authenticate with IAM tokens through `pg-aws_rds_iam`, with `aws_rds_iam_auth_token_generator: dsql` naming the generator registered in `dsql_token.rb`. The `admin` role needs the admin token variant; every other role uses the regular one.
- In `database.yml`, set `advisory_locks: false` (unsupported), `max_age: 2700` (DSQL closes sessions after an hour; the default `pool_jitter` spreads it over 36-45 minutes), and `sslmode: verify-full` with `sslnegotiation: direct` and AmazonRootCA1. Prepared statements work; leave them on.
- Apply the adapter patches from `aws-samples/aurora-dsql-samples` in `dsql_monkey.rb`: no-op `client_min_messages=` and `set_standard_conforming_strings`, `supports_ddl_transactions? = false`. Also skip the ROLLBACK after DSQL has already ended the transaction ([rails/rails#56717](https://github.com/rails/rails/pull/56717)).
- A primary key index with `INCLUDE` columns breaks Rails' primary key detection until [rails/rails#58555](https://github.com/rails/rails/pull/58555) is in your Rails. Backport the patch, or declare `self.primary_key = "id"` in each model.
- Rotation does not prevent every dropped connection. Code that must not fail on one retries `ActiveRecord::ConnectionFailed` itself.

## Transactions under OCC

DSQL tracks the rows each transaction reads and writes. At commit, it rejects the transaction if another one committed a write to any of those rows since this one started. Treat a conflict as expected, not as an error.

- Include `DsqlTransactionable` in `ApplicationRecord` and open every transaction with `retryable_transaction` (retries OCC conflicts with jittered exponential backoff) or `non_idempotent_transaction` (no retry, a marker that you thought about it). Enable the RuboCop cop so a bare `transaction` or `with_lock` fails lint:

  ```yaml
  # .rubocop.yml
  require:
    - ./rubocop/transaction_occ_awareness.rb
  Dsql/TransactionOccAwareness:
    Enabled: true
    Exclude:
      - app/models/concerns/dsql_transactionable.rb
  ```

- A retry re-runs the whole block, so everything the block depends on must be read inside it. A record loaded before the block keeps stale attributes on retry; `reload` or re-`find` it inside.

  ```ruby
  # BAD: on retry, challenge carries the attributes of the failed attempt
  challenge.mark_as_used
  ApplicationRecord.retryable_transaction { challenge.save! }

  # GOOD
  ApplicationRecord.retryable_transaction do
    challenge.reload
    challenge.mark_as_used
    challenge.save!
  end
  ```

- Use `non_idempotent_transaction` when the block has external side effects (mail, API calls) or must use data read before it.
- There are no gap locks. A query that returns no rows adds nothing to the read set, so two concurrent check-then-insert transactions both succeed. Prefer a unique index. Otherwise make them conflict on a parent row: `lock!("FOR KEY SHARE")` when only key columns matter, `lock!` (`FOR UPDATE`) to serialize the whole flow.

  ```ruby
  ApplicationRecord.retryable_transaction do
    user.lock!("FOR KEY SHARE")
    raise Duplicate if user.records.exists?(key: k)
    user.records.create!(key: k)
  end
  ```

- Keep transactions short in time and small in rows. Conflicts are checked over the transaction's wall-clock lifetime, and DSQL limits the rows one transaction may touch. Do slow work (password hashing, HTTP) and checks that need no atomicity (rate-limit counts, preconditions) outside the block.
- Hot rows conflict no matter how often you retry. Lower the write rate: skip writes that change nothing meaningful (only bump `last_activity_at` when it is more than a minute old), defer them to a job, or split hot columns into their own table.
- With no SAVEPOINT, a transaction cannot nest. Open transactions in one layer (controller or service object). A model method that opens one assumes its caller has not.

## Schema

Follow /sorah-guides:sqldef-on-rails, with these differences, all already in the reference `database.rake`:

- psqldef runs with `disable_ddl_transaction: true`, through `script/pdsql`, and retries on `OC000`/`OC001`. DDL conflicts with other DDL and with async index completion on the same cluster.
- `BEFORE_APPLY_SQL` is split on `;` (so no `;` inside literals), and each statement runs in its own psql invocation (one DDL per transaction, and an OCC retry must not re-run DDL that already succeeded). Then the task waits for async jobs.
- Write every index as `create index async` / `create unique index async`.
- After applying the schema, wait. `db:wait_for_jobs` polls `sys.jobs`, and `db:wait_for_indexes` polls for unique indexes that are not yet valid. Each poll opens a new connection, because a connection keeps seeing the catalog as it was when it opened. Deploy code that relies on a new unique index only after it is valid. Pre-deploy: `rails db:migrate db:wait_for_jobs`.
- Decide `NOT NULL` when the table is created; it cannot be added later. A column's type is permanent too. After release, a change to either means add a new column, backfill, switch, drop. Before release, drop the table with `BEFORE_APPLY_SQL` and let psqldef recreate it.
- Keep tables narrow. ActiveRecord selects every column and every read row is conflict surface, and a cluster holds at most 1,000 tables. A `jsonb` column with an expression index is fine for structured data that changes shape.
- There is only the `postgres` database. `db:create` creates your schema and login role, `db:drop` drops the schema, and `db:prepare` only migrates outside development and test.
- `test_dsql_conflicts.sql` (for the spec helper) is applied in every environment, like every schema file. It is an empty table; filter it out of `DatabaseTasks.psqldef` if that bothers you.

## Roles

Two permission roles hold table privileges, granted in every table's `.sql` and managed by psqldef's `manage.privilege`. Login roles get one of them:

```
app_admin   DDL + DML (member of app_user)
app_user    DML only
developer   login, member of app_admin; dev/test only, IAM-mapped to developers' role
<user>      per-developer login role ($USER), member of developer, search_path = its schema
app_<name>  staging/production login role for the app and the pre-deploy task, member of app_admin
```

Use one login role for both the app and the pre-deploy migration, so the tables it creates are owned by the role that uses them. Bootstrap a staging or production cluster as `admin`, one statement per `script/pdsql -- psql -c` (no multi-statement DDL transactions):

```sql
CREATE ROLE app_admin;
CREATE ROLE app_user;
GRANT app_user TO app_admin;
CREATE ROLE app_<name> WITH LOGIN;
GRANT app_admin TO app_<name>;
ALTER ROLE app_<name> SET search_path TO <name>_prd;
AWS IAM GRANT app_<name> TO '<task role arn>';
CREATE SCHEMA IF NOT EXISTS <name>_prd AUTHORIZATION app_<name>;
GRANT USAGE ON SCHEMA <name>_prd TO app_user;
GRANT USAGE, CREATE ON SCHEMA <name>_prd TO app_admin;
GRANT app_admin TO admin;
```

## Local development

Developers share a few long-lived dev and test clusters (created with Terraform). Each gets their own schema on each cluster:

- `rake db:init` (once per cluster, as `admin`) creates the permission roles and `developer`, IAM-mapped to the caller's role. `rake db:create` creates the `<user>` login role and the `<user>_dev` / `<user>_test` schema, with `search_path` set. Run from development, `init`, `create`, `migrate`, `drop` and the wait tasks cover the test cluster as well (`SKIP_TEST_DATABASE=1` to skip). The statements in `init` and `create` that fail on a re-run (an existing role) only warn.
- A cluster allows 10 user-created schemas, so run several clusters per environment. Publish them as an SRV rrset; `rake db:pick_cluster` asks each how many schemas it has and pins the least populated in `tmp/{dev,test}-dsql-cluster.txt`. `DSQL_DEV_HOST` / `DSQL_TEST_HOST` override it.
- Pin files and the user override in `tmp/` fall back to the main checkout from a linked git worktree, so worktrees share one schema.
- `bin/setup` runs `db:pick_cluster`, then `db:create db:migrate`.
- An agent in an isolated sandbox, where `$USER` is shared (e.g. `ubuntu`), runs `rails db:agent_user SESSION_ID=...` first. This writes a dated user and schema name to `tmp/`, which `db:prune_ci PREFIX=agent` expires later. `validate_dsql_user!` refuses shared usernames.
- `script/pdsql` opens psql with a fresh token, as `admin` unless `-U` says otherwise; `-h` takes a host or an environment name. psql's own flags and any other libpq tool go after `--`: `script/pdsql -h development -- psql -c '\dt'`.
- AWS credentials should come with least privilege automatically inside the project, so coding agents can use them as they are.

## Tests

Tests run against the real test cluster. Every support file is in `references/spec/support/`. In `rails_helper.rb`:

```ruby
# Support files register hooks whose order depends on load order.
Rails.root.glob("spec/support/**/*.rb").sort_by(&:to_s).each { |f| require f }

RSpec.configure do |config|
  config.use_transactional_fixtures = false
end
```

Remove `ActiveRecord::Migration.maintain_test_schema!`; `db:migrate` keeps the test schema current.

- No transactional fixtures, since there is no SAVEPOINT. DSQL has no TRUNCATE either, so database_rewinder DELETEs from the tables each example inserted into. `dsql_disable_referential_integrity.rb` makes its trigger toggling a no-op, since DSQL has no triggers.
- TestProf `let_it_be` uses `NoopAdapter`. Each `before_all` block runs in one transaction with OCC retry, so its records cost one COMMIT. Tables written by `before_all` are kept until the group ends. A `let_it_be` record is shared by every example in the group, so pass `reload: true` or `refind: true` to any example that mutates it or creates children of it.
- `:batch_transactions` (opt-in metadata) wraps each example in one lazily-begun, joinable transaction, saving a round trip per write. It is for model specs; avoid it for code that tests `after_commit` or manages its own transactions.
- An `around` hook re-runs an example that failed only with OCC errors, clearing memoized `let`s. DDL from other CI runs on the same cluster causes conflicts even in an isolated schema. database_rewinder cleanup is retried the same way.
- `trigger_dsql_conflict!` forces an OC001 inside the current transaction, for testing retry paths. It needs the `test_dsql_conflicts` table.

  ```ruby
  it "retries on conflict" do
    attempts = 0
    ApplicationRecord.retryable_transaction do
      attempts += 1
      trigger_dsql_conflict! if attempts == 1
    end
    expect(attempts).to eq(2)
  end
  ```

- Use Timecop, not `ActiveSupport::Testing::TimeHelpers`. A token signed at travelled time is rejected ("Signature not yet current"), and only Timecop can be suspended (`Timecop.return`) while the token generator signs.

## CI

CI also runs against real clusters, so most of the work goes into hiding latency and DDL time.

- Region: GitHub-hosted runners run in assorted Azure US regions, and round trips to DSQL differ by up to 7x between them. Run CI clusters in several US regions, publish one SRV rrset per region behind Route 53 latency-based routing, and resolve it from the runner.
- Parallelism: split the suite with parallel_tests over a matrix. `TEST_ENV_NUMBER` already suffixes the test schema. `rake db:measure_latency` records the average `SELECT NOW()` round trip (and the runner's Azure region from `azure.archive.ubuntu.com`) to the job summary. Divide recorded per-file runtimes by it before saving them as the parallel_tests runtime log, so splits do not follow whichever region a past run drew.
- Schema pool (a design to build; there is no reference code for it): creating a schema and applying psqldef from empty takes minutes, much of it waiting for async indexes. Keep pre-built schemas instead:
  - Each CI cluster has a metadata table of pooled schemas, with states `creating → ready → in_use → returned → deleting`.
  - A job claims a random `ready` schema with one atomic `UPDATE ... RETURNING`, applies the branch's schema with `ENABLE_DROP=1 rake db:migrate db:wait_for_indexes`, and runs the suite.
  - Whatever the result, the job triggers a check-in workflow (`workflow_dispatch`) that drops the schema and creates a fresh one at main. A PR's schema change may not be reversible, so the pool never reverts a schema.
  - A push to main updates `ready` schemas in place. A scheduled reaper recovers schemas stuck `in_use` for hours, drops returned and failed ones, and refills to the per-cluster limit.
  - The maintenance workflows fan out per cluster and per schema with a dynamic matrix.
  - If the pool is empty, a job creates its own schema (`db:init db:create db:migrate db:wait_for_indexes`) and drops it afterwards. Name such schemas and roles `<prefix>_<YYYYMMDD>_<id>` through `DSQL_CLUSTER_USER` and `DSQL_TEST_SCHEMA`, so a scheduled `rake db:prune_ci PREFIX=<prefix> THRESHOLD=<seconds>` can remove the ones jobs left behind, IAM mappings included.
