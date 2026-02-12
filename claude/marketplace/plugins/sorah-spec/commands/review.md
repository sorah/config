---
description: Review a spec file through an exhaustive interview session to resolve all ambiguities
argument-hint: <spec-file-path>
---

Conduct a specification interview session. Review a spec file, identify all ambiguities, gaps, and missing details, then interview the spec author about **literally anything** until the spec is complete and unambiguous. This is an in-depth, exhaustive process — do not stop early. Ask about every detail: naming, defaults, error messages, edge cases, field types, method signatures, return values, logging payloads, configuration keys, test expectations, and more. Continue until confident that an implementor could build the feature from the spec alone without further questions.

## Input

The user provides a spec file path as argument: $ARGUMENTS

If no argument is given, ask the user which spec file to review.

## Preparation Phase

Before asking any questions:

1. **Read the spec file** thoroughly
2. **Read all referenced files** — follow every file reference, schema file, existing code mentioned in the spec
3. **Read project conventions** — check for project-level documentation (CLAUDE.md, style guides, architecture docs, knowledge files) relevant to the spec's domain
4. **Explore existing codebase** for related models, modules, patterns, and conventions that the spec's implementation would interact with
5. **Check for inconsistencies** — field collisions in schemas, index types, formula errors, duplicated sections, naming mismatches between spec and code

## Interview Phase

Ask questions in focused batches of 2-4 using the AskUserQuestion tool. Group related questions together. **After every batch of answers, update the spec file before continuing to the next batch.** This keeps the spec current throughout the session and prevents losing context in long interviews.

Interview sessions are expected to be lengthy — often 10+ rounds of questions. Do not rush or skip areas. Cover these areas systematically, and revisit earlier areas if later answers reveal new ambiguities.

Project-specific conventions (CLAUDE.md, style guides, knowledge docs) and framework-specific skills always take priority — adapt the checklist below to match the actual project's stack and patterns discovered during the Preparation Phase.

### Data Model
- Schema correctness (types, naming, constraints, field numbering)
- Database schema correctness (indexes, constraints, column types, defaults)
- Serialization approach
- Resource identifier patterns

### Architecture & Design
- Class/module structure (where logic lives, how it's organized)
- Interface design (method signatures, return types, error handling)
- Naming conventions (classes, methods, files)
- Extensibility patterns

### Behavior & Logic
- Happy path flow end-to-end
- Error conditions and how each is handled
- Edge cases (concurrency, race conditions, nil/null values)
- Validation rules and where they're enforced

### Integration
- How new code interacts with existing models and modules
- Configuration values and their defaults
- Encryption/secrets requirements
- Background job design
- Logging plan (what events at what levels, what payload data)

### Security
- Credential handling (hashing, comparison, storage)
- Replay prevention mechanisms
- Rate limiting strategy and defaults
- Sensitive data that must not be logged

### Operations
- Development setup and fixtures
- Purging/cleanup strategies
- Key rotation handling

### Scope & Deliverables
- What's explicitly in/out of scope
- Dependencies on future work
- Expected file deliverables (code, specs, docs)
- For each documentation deliverable: what it should cover and what it should defer to source files

## Rules

- **Never assume** — if something is ambiguous, ask. Even if you think you know the answer, confirm with the user.
- **Flag bugs** — if you find errors in existing code or schema files referenced by the spec, call them out before asking questions.
- **Be specific** — provide concrete options with descriptions when asking questions. Don't ask open-ended questions when you can offer informed choices.
- **Update iteratively** — after every batch of answers (2-4 questions), update both the spec body AND the Current Status section before asking the next batch. This is critical for long interview sessions — never accumulate more than one batch of unapplied answers.
- **Polish language** — when updating the spec, improve the readability of surrounding prose, not just the newly added content. Fix awkward phrasing, tighten wordy sentences, and ensure consistent tone throughout. The spec should read as a coherent, well-edited document — not a patchwork of interview answers stapled together.
- **Spec completeness** — the spec must be self-contained. Inline all design details, schemas, and decision rationale directly in the spec. A reader should not need to open other files to understand the full design.
- **Check for TODOs** — find and resolve every TODO in the spec. TODOs that are deliverables (create a file during implementation) should be reworded as clear action items, not questions.
- **Verify completeness** — at the end, grep the spec for remaining TODOs and ambiguous language ("TBD", "maybe", "possibly", "to be decided").
- **Respect existing patterns** — when asking about implementation approaches, always include an option that follows existing codebase conventions.
- **Repeat until done** — keep asking questions until the spec is complete enough for an implementor to build the feature without further clarification. Do not stop early. If you think you're done, re-read the spec one more time and look for anything still vague or underspecified. The interview is expected to be long and thorough.

## Current Status Section

The spec must always end with a "Current Status" section that tracks interview progress:

**During interview** (keep it concise):
- List interview areas already covered with brief summary of decisions made
- List remaining areas to be questioned, with approximate number of remaining questions

Example:
```
## Current Status

Interview in progress.

Covered:
- Data Model: schema fields finalized, index fixed to non-unique
- Architecture: service object pattern, module structure decided

Remaining (~12 questions):
- Behavior & Logic: flow details, error handling
- Security: rate limiting defaults, replay prevention
- Operations: setup, purge job
- Scope & Deliverables: docs file scope
```

**After interview completes**, expand into a Checklist + Updates format suitable for implementors:
- Implementation checklist with checkboxes for each deliverable
- Updates subsection for dated progress entries
- Include instruction: "Implementors MUST keep this section updated as they work."
