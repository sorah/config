---
description: Validate that a completed implementation complies with its spec, surfacing gaps and discrepancies for human resolution
argument-hint: <spec-file-path>
---

Validate a completed implementation against its spec. Read both the spec and all implemented code, then systematically compare them. Surface every gap, discrepancy, or deviation for the user to resolve — do not silently accept or fix differences. The goal is to ensure the implementation faithfully reflects the spec, or to explicitly document where and why they diverge.

## Input

The user provides a spec file path as argument: $ARGUMENTS

If no argument is given, ask the user which spec file to validate.

## Preparation Phase

Before comparing anything:

1. **Read the spec file** thoroughly — understand the full design, all deliverables, schemas, behavior descriptions, error handling, and edge cases
2. **Read all referenced files** — schema files, existing code, related specs mentioned in the spec
3. **Review recent changes** — use `git diff` and recent commits up to the primary branch to understand what changed as part of this implementation. This gives context on the actual scope of changes and helps identify modifications the spec may not have anticipated
4. **Read project conventions** — check for project-level documentation (CLAUDE.md, style guides, architecture docs, knowledge files) relevant to the spec's domain. Project-specific conventions and framework-specific skills always take priority over general approaches
5. **Identify all deliverables** — build a complete list of files and changes the spec calls for, from the Deliverables section and the Current Status checklist
6. **Read every delivered file** — read each file listed in the deliverables. If a file doesn't exist, note it as missing. If the spec mentions modifications to existing files, read those files too
7. **Explore surrounding code** — look at related modules, tests, and integration points to understand how the implementation fits into the broader codebase

## Validation Phase

Compare the implementation against the spec systematically. Check each area below and record every discrepancy found, no matter how small.

### Deliverable Completeness

- Are all files listed in the spec's deliverables present?
- Are all checklist items in Current Status marked as complete?
- Are there implemented files not mentioned in the spec?

### Data Model

- Do database migrations, schemas, or data definitions match the spec exactly?
- Column types, constraints, defaults, indexes — do they all match?
- Are field names consistent between the spec and implementation?

### Architecture & Structure

- Does the class/module structure match what the spec describes?
- Are classes, modules, and files named as the spec specifies?
- Does the code live where the spec says it should?
- Do method signatures (parameters, return types) match?

### Behavior & Logic

- Does the happy path flow match the spec's description?
- Are all error conditions handled as the spec specifies?
- Are edge cases covered?
- Do validation rules match?
- Are error messages and response formats as specified?

### Integration

- Does the code interact with existing modules as the spec describes?
- Are configuration values and defaults correct?
- Do background jobs, logging, and events match the spec?

### Security

- Are credential handling, rate limiting, and access control implemented as specified?
- Are sensitive data protections in place as described?

### Tests

- Do tests cover the scenarios the spec calls for?
- Are test expectations consistent with the spec's behavior descriptions?

## Updating Current Status

After the Validation Phase and before asking the user about any discrepancies, update the spec's Current Status section to reflect that validation is in progress and list all found discrepancies:

```
## Current Status

Validation in progress.

### Checklist
- [x] First deliverable
- [x] Second deliverable
...

### Discrepancies

(Recording as validation proceeds)

### Updates

- YYYY-MM-DD: Previous updates...
- YYYY-MM-DD: Validation started
```

Add a `### Discrepancies` subsection under Current Status. Initially populate it with all discrepancies found during the Validation Phase (all marked as "pending"). Then continue updating incrementally — after each batch of user questions is resolved, update the resolution status for those discrepancies. The spec must always reflect the current state of validation.

Discrepancy entries should be concise:

```
### Discrepancies

- **Field type mismatch in users table** — spec says `jsonb`, impl uses `text`. Resolution: pending
- **Missing rate limiter middleware** — spec requires 5 req/min, not implemented. Resolution: impl needs fixing
- **Extra index on created_at** — not in spec, added by implementor. Resolution: spec updated
```

## Reporting Discrepancies

For each discrepancy found, report it to the user using AskUserQuestion with specific options for resolution. Group closely related discrepancies into a single question when they share the same root cause, but do not batch unrelated issues together.

For each discrepancy, clearly state:
- **What the spec says** — quote or reference the specific section
- **What the implementation does** — reference the specific file and line
- **The nature of the difference** — missing, extra, or divergent

Offer resolution options appropriate to the discrepancy. Common patterns:

- **Spec is correct, implementation needs fixing** — the implementation should be updated to match the spec
- **Implementation is correct, spec needs updating** — the spec was wrong or outdated; update the spec to match reality
- **Intentional deviation** — the deviation was a deliberate decision; document it in the spec's Updates section
- **Needs further discussion** — the right answer isn't clear; flag for deeper review

Do not fix code or update the spec yourself. Present findings and let the user decide how to handle each discrepancy. Wait for the user's decision on each batch before continuing to the next. **After each batch is resolved, update the Discrepancies section in Current Status with the resolution.**

## Rules

- **Be exhaustive** — check every deliverable, every field, every behavior. Do not skip areas because they "look fine."
- **Be precise** — reference specific spec sections and specific file:line locations. Vague reports are not actionable.
- **Do not fix anything** — this is a validation pass, not an implementation pass. Report discrepancies; do not resolve them.
- **Do not assume intent** — if the implementation differs from the spec, do not guess whether it was intentional. Ask.
- **Group related issues** — if a naming mismatch cascades through multiple files, report it as one discrepancy with all affected locations listed, not as separate issues.
- **Report clean results too** — after all checks, summarize which areas passed validation with no issues. This confirms those areas were actually checked.
- **Respect the spec as baseline** — compare implementation against spec, not the other way around. The spec is the reference document; deviations are measured from it.

## Completion

After all discrepancies have been reported and the user has decided on each:

1. Update the Current Status section with final results — mark validation as complete, record the resolution for every discrepancy, and add a dated Updates entry summarizing the outcome
2. Summarize the validation results to the user — how many discrepancies found, how many resolved, how many deferred
3. List any action items that remain (code fixes, spec updates, further discussion needed)
4. If the user asked you to apply any fixes or spec updates during the session, confirm those changes were made
