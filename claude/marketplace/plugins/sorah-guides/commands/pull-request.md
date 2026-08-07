---
description: Create a GitHub pull request following sorah's commit/PR style
argument-hint: "[message-only]"
---

Load the **commit-style** skill and apply its conventions to PR titles and descriptions.

## Instructions

$ARGUMENTS

### Step 1: Analyze the branch

1. Determine the current branch name and the base branch (main/master).
2. **Halt immediately** if the current branch is the primary branch (main or master). Ask the user what to do.
3. Run `git log <base>..HEAD` and `git diff <base>...HEAD` to understand all commits on this branch.

### Step 2: Consider a stacked PR

Stacked PRs are handled by the **gh-stack** skill, which is not part of this plugin. **Halt immediately** whenever a stack is called for but that skill is unavailable — tell the user the gh-stack skill is missing and ask how to proceed. Never improvise a stack with raw `gh` or `git` commands.

**If the branch is already part of a stack** (`gh stack view --json` exits 0 and lists the current branch), or the user asked for a stacked PR: load the **gh-stack** skill and follow it instead of the `gh pr create` flow in Step 4. `gh pr create` does not maintain stack bases.

**Otherwise**, judge whether the branch is better submitted as a stack. Suggest stacking when the commits divide into parts that can be reviewed on their own and splitting them measurably lightens the reviewer's load:

- A preparatory change (refactor, rename, extraction, dependency bump) that stands on its own, followed by the change that depends on it
- Parts with different reviewer audiences (e.g. infrastructure/schema vs. application code)
- A diff large enough that reviewing it as a single unit is a burden, with a natural seam to cut along

Do not suggest stacking when the change is one cohesive unit, when the split parts would not build or pass tests independently, or when the pieces are meaningless apart from each other. A small PR does not need splitting.

When stacking is worthwhile, present the proposed layers (branch names and which commits go where) and **wait for approval** — restructuring rewrites branch history. On approval, load the **gh-stack** skill and follow it to build and submit the stack; compose each PR's title and description with Step 3 below. Skip this step when the argument contains "message-only" — mention the suggestion, but do not restructure.

### Step 3: Compose title and description

**Title:** Follow the same conventions as a commit subject line — short (under 70 chars), lowercase imperative verbs, contextful verbs, optional `prefix:` pattern. No trailing period.

**Description:**

- For a **single-commit branch**: use the commit subject as title and commit body as description. If the commit has no body, the description can be empty or a single sentence.
  - When taking a commit body into the PR description, **unwrap hard-wrapped lines** within each paragraph into a single line. Commit messages wrap at ~72 chars, but GitHub renders embedded newlines as `<br>`, producing hard-to-read paragraphs. Preserve paragraph breaks (blank lines) but join consecutive non-blank lines with a space.
- For a **multi-commit branch**: write a concise summary title, then in the description, explain individual commits under headings or bullet points. Use Markdown naturally.

**Never include:**
- Test procedures, test plans, or QA checklists
- Task lists or TODO checkboxes
- "How to test" sections
- Boilerplate footers (except Co-Authored-By trailers if applicable)

### Step 4: Create or output

**If argument contains "message-only":**

Output the composed title and description in a fenced Markdown code block and stop. Do not push or create a PR.

````
```markdown
Title: ...

---

Description body here...
```
````

**Otherwise:**

1. Push the branch to origin with `git push -u origin HEAD`.
2. Create the PR with `gh pr create --title "..." --body "..."`. Use a HEREDOC for the body.
3. Return the PR URL.

For a stacked branch, submit through the **gh-stack** skill rather than these steps, then apply the composed titles and descriptions with `gh pr edit` — `gh stack submit` auto-generates them.
