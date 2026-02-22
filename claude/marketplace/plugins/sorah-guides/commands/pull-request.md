---
description: Create a GitHub pull request following sorah's commit/PR style
argument-hint: "[message-only]"
---

Load the **Git Commit Style** skill and apply its conventions to PR titles and descriptions.

## Instructions

$ARGUMENTS

### Step 1: Analyze the branch

1. Determine the current branch name and the base branch (main/master).
2. **Halt immediately** if the current branch is the primary branch (main or master). Ask the user what to do.
3. Run `git log <base>..HEAD` and `git diff <base>...HEAD` to understand all commits on this branch.

### Step 2: Compose title and description

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

### Step 3: Create or output

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
