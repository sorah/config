---
name: spec-conventions
description: This skill should be used when the user asks about "spec file format", "spec conventions", "spec vs docs", "current status section", "specification structure", "how to write a spec", "spec deliverables", or "self-contained spec". Provides conventions for writing implementation-ready specification documents.
version: 0.1.0
---

# Spec File Conventions

Conventions for writing implementation-ready specification documents that serve as the single source of truth for feature design and implementation.

## Spec Files vs Documentation Files

Projects often maintain two distinct documentation layers. Understand the distinction to keep each layer focused.

### Spec Files

- **Purpose**: Single source of truth for design and implementation decisions
- **Audience**: Implementors and reviewers
- **Content**: Full design details — schemas, field definitions, decision rationale, implementation notes
- **Lifecycle**: Created before implementation, updated progressively during implementation
- **Self-contained**: A reader should understand the full design without opening other files

### Documentation Files

- **Purpose**: Quick-reference guides after implementation
- **Audience**: Developers using the feature
- **Content**: Usage-focused ("how to use"), not "how it was designed"
- **Brevity**: Avoid duplicating definitions — point to source files (.sql, .proto, .rb, config files)
- **No historical context**: Omit decision rationale and alternatives considered

When a spec lists documentation files as deliverables, verify their scope is clear. The spec itself must contain enough inline detail to be self-contained — never defer design details to documentation files.

## Spec File Structure

A well-structured spec includes:

1. **Title and overview** — what the feature does and why it's needed
2. **Data model** — include full DDL or schema definitions, not just prose descriptions
3. **Architecture** — name concrete classes/modules; specify where each piece of logic lives
4. **Behavior** — cover the happy path end-to-end, then every error condition and edge case
5. **Integration** — specify which existing modules are touched and how
6. **Security considerations** — credential handling, rate limiting, audit logging, sensitive data
7. **Operations** — setup steps, cleanup/purge strategies, key rotation procedures
8. **Scope** — explicitly state what's in and out; note dependencies on future work
9. **Deliverables** — enumerate every file to create or modify
10. **Current Status** — interview or implementation progress (see below)

## Self-Containment Principle

Inline all design details directly in the spec:

- Full schema definitions (SQL DDL, protobuf, JSON schemas, etc.)
- Field-level tables with types, constraints, and descriptions
- Decision rationale for non-obvious choices
- Error handling behavior for each failure mode

A reader should never need to open another file to understand the complete design.

## Resolving TODOs

Before a spec is considered interview-complete:

- Every TODO must be resolved
- TODOs representing open design questions must be resolved through discussion; inline the decision and rationale directly
- TODOs representing implementation tasks should be reworded as clear action items in the deliverables or checklist
- Grep the spec for ambiguous language: "TBD", "maybe", "possibly", "to be decided"

## Current Status Section

Every spec must end with a "Current Status" section. Its format differs by phase. See `references/current-status-format.md` for detailed examples across interview and implementation phases.

### During Interview

Keep concise — list covered areas with key decisions and remaining areas with rough question count:

```
## Current Status

Interview in progress.

Covered:
- Data Model: field types finalized, indexes decided
- Architecture: service object pattern chosen

Remaining (~8 questions):
- Behavior & Logic: error handling details
- Security: rate limiting defaults
- Operations: cleanup strategy
```

### After Interview / During Implementation

Expand into a checklist and updates format:

```
## Current Status

Implementation in progress. Implementors MUST keep this section updated as they work.

### Checklist
- [ ] Create database migration
- [ ] Implement service object
- [ ] Add request specs
- [ ] Write documentation

### Updates

- YYYY-MM-DD: Migration created, model specs passing
- YYYY-MM-DD: Service object implemented with error handling
```

## Additional Resources

### Reference Files

- **`references/current-status-format.md`** — Detailed examples of Current Status sections across interview and implementation phases
