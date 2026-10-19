create table test_dsql_conflicts (
    id uuid primary key default gen_random_uuid(),
    counter integer not null default 0,
    created_at timestamp(6) with time zone not null default now(),
    updated_at timestamp(6) with time zone not null default now()
);

grant all privileges on test_dsql_conflicts to app_admin;
grant select, insert, update, delete on test_dsql_conflicts to app_user;
