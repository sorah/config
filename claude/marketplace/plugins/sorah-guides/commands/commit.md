---
description: Create git commit(s) following sorah's commit style conventions
argument-hint: "[split]"
---

Load the **Git Commit Style** skill and follow its conventions precisely — subject line style, prefix pattern, contextful verbs, lowercase imperative, and body guidelines.

## Instructions

Review all staged and unstaged changes, then create git commit(s).

$ARGUMENTS

### When argument contains "split"

Commit changes in logical, granular increments. Each commit should represent a single task or a functional unit. Ensure that the codebase remains stable and error-free at every commit point; do not commit code that is broken or fails to execute.

Before committing, present the proposed split plan (which files/hunks go into which commit, with draft subject lines) and wait for approval.

### Otherwise

Commit all changes together in a single commit.
