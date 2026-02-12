---
name: Rails Spec Interview
description: This skill should be used when conducting spec interviews or implementing specs for Ruby on Rails projects, or when the spec mentions "Rails", "ActiveRecord", "ActiveJob", "concerns", "migrations", "Rails.configuration", or "request specs". Provides Rails-specific interview and implementation checklist items.
version: 0.1.0
---

# Rails Spec Interview Guide

Rails-specific checklist for spec interviews and implementation. For underlying Rails conventions, consult the `sorah-guides:rails` skill. Project-specific conventions always take priority.

## Interview Checklist

When interviewing a spec for a Rails project, verify these areas are fully specified:

### Data Model
- Migration details: column types, defaults, null constraints, index definitions
- Unique vs non-unique indexes; composite index column order
- Which validations live at model level vs database constraint level
- Association dependent behavior and foreign key constraints

### Architecture & Design
- Which concerns are extracted and what they encapsulate
- Where business logic lives: model callbacks vs service objects vs controllers
- Controller action responsibilities and before_action filters

### Integration
- Configuration approach: `Rails.configuration.x.*` namespacing, ENV access policy
- Encryption strategy for sensitive attributes
- Background job classes, queue names, retry policies
- Logging: which events, at what levels, with what payload
- Which existing concerns the new code interacts with
- Mailer classes and delivery method

### Testing
- Request spec expectations: status codes, response bodies, error formats
- Model spec coverage: validations, associations, scopes
- Test data strategy: FactoryBot patterns, `let_it_be` usage
- Time-dependent test approach

### Security
- Password hashing mechanism
- Parameter filtering for sensitive request params
- Audit logging requirements

### Operations
- `bin/setup` changes: seed data, fixture files
- Rake tasks needed for data migrations or cleanup
- Key rotation strategy for encrypted attributes
