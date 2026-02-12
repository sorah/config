---
description: Implement a feature from a completed spec file, updating the spec's Current Status as you go
argument-hint: <spec-file-path>
---

Implement a feature based on a well-defined spec file. The spec is the single source of truth — follow it precisely. Work through deliverables methodically, updating the spec's Current Status section after completing each task.

## Input

The user provides a spec file path as argument: $ARGUMENTS

If no argument is given, ask the user which spec file to implement.

## Preparation Phase

Before writing any code:

1. **Read the spec file** thoroughly — understand the full design before starting
2. **Read all referenced files** — schema files, existing code, related specs mentioned in the spec
3. **Read project conventions** — check for project-level documentation (CLAUDE.md, style guides, architecture docs, knowledge files) relevant to the spec's domain. Project-specific conventions and framework-specific skills always take priority over general approaches
4. **Explore existing codebase** for related models, modules, patterns, and conventions that the implementation must follow or integrate with
5. **Verify the spec is implementation-ready** — check that the Current Status section indicates the interview is complete and a checklist exists. If the spec still contains unresolved TODOs, ambiguous language ("TBD", "maybe", "possibly"), or lacks a checklist, stop and inform the user that the spec needs further review before implementation

## Initializing Current Status

If the spec's Current Status section is still in interview format (no checklist), convert it to the implementation format before starting work:

```
## Current Status

Implementation in progress. Implementors MUST keep this section updated as they work.

### Checklist
- [ ] First deliverable
- [ ] Second deliverable
...

### Updates

(No updates yet)
```

Derive checklist items from the spec's deliverables section. Each item should be a concrete, completable task.

## Implementation Phase

Work through the checklist items in a logical order — respect dependencies between items (e.g., migrations before models, models before services, services before API endpoints).

For each checklist item:

1. **Plan** — re-read the relevant spec section; identify the files to create or modify
2. **Implement** — write the code following the spec's design exactly. Adhere to project conventions and framework-specific skills
3. **Verify** — run relevant tests or checks if the project has them
4. **Update the spec** — mark the checklist item as done (`[x]`) and add a dated entry to the Updates subsection describing what was completed and any notable decisions or discoveries

**Update the spec after every completed item.** Do not batch updates. The spec must reflect the current state of implementation at all times.

## Rules

- **The spec is authoritative** — implement what the spec says. If the spec's design conflicts with what seems right, follow the spec and flag the concern to the user rather than silently deviating.
- **Follow project conventions** — adhere to CLAUDE.md, style guides, and project-specific knowledge docs. These take priority for implementation details not covered by the spec.
- **Follow framework-specific skills** — let loaded skills guide language and framework idioms (naming, patterns, testing approaches).
- **Ask before deviating** — if an implementation detail is unclear or seems wrong, ask the user using AskUserQuestion rather than guessing. Reference the specific spec section.
- **Flag discovered issues** — if you find bugs in existing code, spec inconsistencies, or missing edge cases during implementation, note them in the Updates section and raise them with the user.
- **Keep the spec current** — update the Current Status section after every completed checklist item. Add a dated entry to Updates with a brief summary of what was done. This is non-negotiable.
- **One task at a time** — complete each checklist item fully before moving to the next. Do not leave items partially done.
- **Respect scope** — implement only what the spec defines. Do not add features, refactor surrounding code, or make improvements beyond the spec's deliverables.

## Completion

When all checklist items are done:

1. Re-read the full spec and verify every deliverable has been addressed
2. Update the Current Status header to "Implementation complete"
3. Add a final Updates entry summarizing the completed implementation
4. Inform the user that implementation is complete and list any issues or concerns discovered during the process
