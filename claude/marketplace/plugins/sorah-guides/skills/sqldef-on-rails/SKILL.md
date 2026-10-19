---
name: sqldef-on-rails
description: This skill should be used when a Rails app manages its PostgreSQL schema declaratively with psqldef (sqldef) instead of ActiveRecord migrations, or when setting that up, changing a table, or replacing `db/migrate`. Signs include `db/schema/*.sql`, a `psqldef` call in a rake file, `BEFORE_APPLY_SQL`, `ENABLE_DROP`, no `db/migrate` directory or `schema.rb`, or the user mentioning "sqldef", "psqldef", "declarative schema", "schema as SQL", or "drop Rails migrations", even if they only say "add a column" in such an app. Provides the schema file layout, the rake tasks that replace migrations, psqldef configuration, non-declarative changes, and installation. Project-specific conventions always take priority.
version: 0.1.0
---

# psqldef on Rails

Running a Rails app's PostgreSQL schema with [psqldef](https://github.com/sqldef/sqldef) instead of ActiveRecord migrations: the desired schema is a set of `CREATE` statements, and psqldef diffs it against the live database and applies the difference. Project-specific conventions (CLAUDE.md, `docs/`) always take priority.

For Aurora DSQL, read /sorah-guides:dsql-on-rails as well; it builds on this setup and replaces several tasks.

## The model

- The schema is `db/schema/*.sql`, one file per table, holding its `CREATE TABLE`, its indexes and its `GRANT`s. The rake task concatenates the files in sorted order and hands psqldef one desired schema.
- There is no `db/migrate/` and no `schema.rb`/`structure.sql`. The `.sql` files are the source of truth, and reviewers read the diff of the desired state, not a migration.
- A schema change ships in the same commit as the code that uses it, never as a preparatory commit.
- `rake db:migrate` applies the files; `rake db:migrate:status` shows the plan (`--dry-run`). Read the plan before applying anything that drops or rewrites.
- psqldef only expresses the end state, plus rename hints. Renaming a table or column without the hint looks like drop-and-add, and a backfill does not exist in the file at all (see below).

```sql
-- db/schema/widgets.sql
create table widgets (
    id uuid primary key default gen_random_uuid(),
    owner_id uuid not null references owners (id),
    name varchar(64) not null,
    created_at timestamp(6) with time zone not null default now(),
    updated_at timestamp(6) with time zone not null default now()
);

create index idx_widgets_owner_id on widgets (owner_id);

grant all privileges on widgets to app_admin;
grant select, insert, update, delete on widgets to app_user;
```

Write a comment on a column whose meaning the name does not carry (an enum's values, an encoded payload). It is the only schema documentation there is.

## Rake tasks

`references/database.rake` is a complete `lib/tasks/database.rake` for plain PostgreSQL; copy it and adjust. What it does:

- Clears Rails' `db:schema:*`, `db:migrate*`, `db:rollback`, `db:test:*`, `db:setup` and `db:prepare`, so nothing loads or dumps `schema.rb` or looks for migrations. `db:setup` and `db:prepare` are redefined as `db:create` + `db:migrate` (+ `db:seed`), so the stock `bin/setup` and `bin/docker-entrypoint` keep working. `db:create` and `db:drop` stay as Rails defines them.
- `DatabaseTasks.psqldef` concatenates the schema files into a tempfile and runs psqldef with the connection from `config_for(:database)`, merged with `DATABASE_URL` when set.
- `--config-inline target_schema:` comes from `schema_search_path`, so an app living in a non-`public` schema is diffed against that schema only.
- `manage.privilege` makes psqldef apply the `GRANT`s for the listed roles. Grants only widen: psqldef never REVOKEs, so removing a table's file or narrowing a grant does not break a deploy, and narrowing needs a manual `REVOKE`.
- Drops (`DROP TABLE`, `DROP COLUMN`, `DROP INDEX`) are skipped unless `ENABLE_DROP=1`. Pass it deliberately, after reading the dry run.
- In development, `db:migrate` applies to the development and test databases together; setting `SKIP_TEST_DATABASE` or `DATABASE_URL` limits it to one.
- Connection settings, including `sslmode`/`sslrootcert`, go to psqldef and psql as `PG*` environment variables.

The permission roles in the example (`app_admin` for DDL+DML, `app_user` for DML) are a convention, not a requirement: drop the `manage` option and the `GRANT`s if the app connects as the table owner.

## Renames and other changes beyond the end state

Rename a table or column with psqldef's annotation. Remove the annotation once every environment has applied it:

```sql
create table widgets ( -- @renamed from=gadgets
    id uuid primary key default gen_random_uuid(),
    name varchar(64) not null, -- @renamed from=title
    ...
);
```

`BEFORE_APPLY_SQL` holds statements that run before the diff is applied, for what the annotation cannot express: type changes needing `USING`, revokes, dropping something to recreate it.

```sh
# narrow a grant psqldef will not revoke
BEFORE_APPLY_SQL='revoke delete on widgets from app_user' rake db:migrate
```

Data backfills belong in a rake task or a one-off script, run between deploying the nullable column and making it `not null`. Record each such step in the PR description; nothing in the repository replays it.

When the same change must reach staging and production, the deploy runs `rake db:migrate` with the same `BEFORE_APPLY_SQL`, or someone runs it by hand first. Pick one per project and write it down in its database doc.

## Rails settings

- `config.active_record.dump_schema_after_migration = false` in every environment. There is nothing to dump.
- `config.active_record.migration_error = false` (or remove the `:page_load` line) in development. With no migrations it does nothing useful.
- Remove `ActiveRecord::Migration.maintain_test_schema!` from `rails_helper.rb`. The test database is kept current by `db:migrate` in development and by CI running `db:migrate` before the suite.
- ActiveRecord reads columns from the live database, so models need no change. A model whose primary key Rails cannot detect declares `self.primary_key`.

## Installing psqldef

Pin the version everywhere psqldef runs, so a dry run on a laptop plans the same statements CI and the deploy will run.

```toml
# mise.toml
[tools]
"aqua:sqldef/sqldef/psqldef" = "3.11.20"
```

```dockerfile
# Dockerfile (builder stage)
RUN --mount=type=tmpfs,target=/tmp/psqldef \
    ( cd /tmp/psqldef && curl -SsfLO "https://github.com/sqldef/sqldef/releases/download/v3.11.20/psqldef_linux_$(uname -m | sed 's/x86_64/amd64/;s/aarch64/arm64/').tar.gz" ) \
 && printf '%s\n' "<sha256>  /tmp/psqldef/psqldef_linux_arm64.tar.gz" "<sha256>  /tmp/psqldef/psqldef_linux_amd64.tar.gz" | sha256sum -c --strict --ignore-missing - \
 && tar xf /tmp/psqldef/psqldef_linux_*.tar.gz -C /usr/local/bin
# final stage
COPY --from=builder /usr/local/bin/psqldef /usr/local/bin/psqldef
```

Take the checksums from the release's checksum file and update them with the version.

## Deploying

Apply the schema in a pre-deploy step (an ECS one-off task, a Kubernetes Job, a release phase) that runs the new image before the new code serves traffic:

```sh
bundle exec rails db:migrate
```

Since the new code meets the new schema only after it is applied, and old code keeps running against it during the rollout, every change must be compatible with the previous release: add first, switch code, drop later with `ENABLE_DROP=1`.

## CI

Run `rake db:create db:migrate` before the suite, against an empty database. The `.sql` files describe the end state, so a schema whose history went through renames or `BEFORE_APPLY_SQL` still applies from scratch.

To show reviewers what a PR will do to a deployed database, run psqldef with `--dry-run` against a database at the main branch's schema and post the plan, so any `DROP` or skipped revoke is seen before merge. `--check` exits 2 when DDL would be applied, for a drift gate.
