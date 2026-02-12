# Current Status Section Format

Detailed examples and guidelines for the Current Status section that ends every spec file.

## Purpose

The Current Status section serves two audiences:

1. **During interview**: Tracks what's been discussed and what remains
2. **During implementation**: Tracks progress and communicates status to team

## Interview Phase Format

During spec interviews, keep the Current Status section concise. Focus on:

- Areas already covered with key decisions
- Remaining areas with rough question count estimate

### Example: Early Interview

```markdown
## Current Status

Interview in progress.

Covered:
- Data Model: User table schema defined, indexes on email (unique) and org_id

Remaining (~15 questions):
- Architecture: Service layer design, concern structure
- Behavior & Logic: Registration flow, error handling
- Integration: Email service, background jobs
- Security: Password hashing, rate limiting
- Operations: Development setup, data migration
- Scope & Deliverables: Documentation plan
```

### Example: Late Interview

```markdown
## Current Status

Interview in progress.

Covered:
- Data Model: Full schema with 3 tables, all indexes defined
- Architecture: UserService with CreateUser and UpdateUser commands
- Behavior & Logic: Registration, login, password reset flows specified
- Integration: ActionMailer for emails, Sidekiq for background jobs
- Security: bcrypt for passwords, 5 req/min rate limit on auth endpoints

Remaining (~3 questions):
- Operations: Seed data format
- Scope & Deliverables: Confirm final file list
```

## Implementation Phase Format

After interview completes, expand into Checklist + Updates format.

### Example: Implementation Start

```markdown
## Current Status

Interview complete. Implementation in progress.

Implementors MUST keep this section updated as they work.

### Checklist

- [ ] Database migration for users table
- [ ] Database migration for user_sessions table
- [ ] User model with validations
- [ ] UserSession model
- [ ] UserService::CreateUser command
- [ ] UserService::UpdateUser command
- [ ] PasswordHasher utility
- [ ] Rate limiter middleware
- [ ] Request specs for registration endpoint
- [ ] Request specs for login endpoint
- [ ] Unit tests for UserService commands
- [ ] docs/users.md documentation

### Updates

(No updates yet)
```

### Example: Mid-Implementation

```markdown
## Current Status

Interview complete. Implementation in progress.

Implementors MUST keep this section updated as they work.

### Checklist

- [x] Database migration for users table
- [x] Database migration for user_sessions table
- [x] User model with validations
- [x] UserSession model
- [ ] UserService::CreateUser command
- [ ] UserService::UpdateUser command
- [x] PasswordHasher utility
- [ ] Rate limiter middleware
- [ ] Request specs for registration endpoint
- [ ] Request specs for login endpoint
- [ ] Unit tests for UserService commands
- [ ] docs/users.md documentation

### Updates

- 2025-01-15: Migrations created, models with validations passing. PasswordHasher uses bcrypt with cost factor 12.
- 2025-01-16: Discovered edge case — email uniqueness needs case-insensitive index. Updated migration to use citext extension.
```

### Example: Complete

```markdown
## Current Status

Implementation complete.

### Checklist

- [x] Database migration for users table
- [x] Database migration for user_sessions table
- [x] User model with validations
- [x] UserSession model
- [x] UserService::CreateUser command
- [x] UserService::UpdateUser command
- [x] PasswordHasher utility
- [x] Rate limiter middleware
- [x] Request specs for registration endpoint
- [x] Request specs for login endpoint
- [x] Unit tests for UserService commands
- [x] docs/users.md documentation

### Updates

- 2025-01-15: Migrations created, models with validations passing.
- 2025-01-16: Email uniqueness uses case-insensitive index via citext.
- 2025-01-17: All service commands implemented with full test coverage.
- 2025-01-18: Rate limiter middleware added. All specs passing.
- 2025-01-19: Documentation written. PR opened.
```

## Guidelines

- **Update frequency**: Update after every meaningful milestone (completed file, discovered issue, design change)
- **Be specific**: Include what was done and any notable decisions or discoveries
- **Flag blockers**: If implementation is blocked, note it in Updates with context
- **Keep checklist aligned**: If the spec's deliverable list changes during implementation, update the checklist to match
