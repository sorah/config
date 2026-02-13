---
name: Git Commit Style
description: This skill should be used when writing git commit messages, creating git commits, composing pull request titles and descriptions, or when the user asks to "commit", "git commit", "write commit message", "pull request", or "PR description". Provides conventions for subject lines, prefix patterns, body content, and verb choices.
version: 0.1.0
---

# Git Commit Style

Conventions for writing git commit messages and pull request descriptions. Project-specific conventions always take priority.

## Subject Line

- Try to keep under 50 characters total
- No trailing period
- Lowercase imperative verbs: `fix`, `add`, `remove`, `use`, `avoid`, `ensure`, `adjust`, `allow`, `enable`, `extract`, `introduce`, `show`, `move`, `roll`
- Capital letter only when starting with a proper noun or class name — never capitalize verbs
- Embed the "why" directly when possible: `avoid enlarging small images`, `avoid double-save on withdraw`
- Technical identifiers kept verbatim: `config.x.asset_file_uploadable`, `event_submission_open?`
- Arrow notation for renames: `ops-lb: rknw -> rknet`

### Contextful Verbs

Prefer specific verbs over generic ones:

- `avoid` or `address` over `fix` for preventive changes
- `extract` over `refactor` when pulling out a concern/class
- `introduce` over `add` when creating a new concept/abstraction
- `reflect` over `update` when syncing with external state
- `gains` for new capabilities (component as subject): `SponsorEvent: gains hero image upload`
- `learns` for new options/parameters: `TitoApi: learns v3.1 pagination`
- `no longer` for behavioral removals: `event_submission_open? no longer gates asset uploads`
- `roll` for dependency updates, `releng` for release engineering, `trigger` for CI/build triggers

## Prefix Pattern

Format: `prefix: rest of subject` — use when the commit targets a specific component.

Prefix types vary by what is being changed:
- **Class/module name** (PascalCase, matching actual name): `SponsorEventAssetFilesController: fix set_asset_file authorization`
- **Method reference** (Class#method): `SponsorEventsController#destroy: avoid double-save on withdraw`
- **View/route path**: `broadcasts/show: sort recipients alphabetically`
- **Feature/epic name** (consistent across a series): `event-assets: begin validation`
- **File or directory**: `Dockerfile: build minimal libvips`, `CI: install libvips-tools`
- **Subsystem/infra name**: `tf/k8s: ...`, `radius: ...`, `grafana: ...`

Omit prefix when:
- The subject already names the target: `Extract GithubInstallation from GenerateSponsorsYamlFileJob`
- Whole-project or obvious-context changes: `roll latest dependencies`, `trigger build for 3.2.10`
- Terse commits: `typo`, `wip`, `oops`

## Body

The most important role of the body is to explain background and context that is **NOT obvious from the diff**. The diff shows what changed; the body explains why it was changed, what problem it solves, or what non-obvious behavior motivated the change.

- Do not repeat what the diff already says — focus on what a reader cannot infer from code alone
- Opening sentence or paragraph: the background, rationale, or problem
- Bullet list with `- ` when enumerating multiple specifics
- Wrap lines at ~72 characters
- Issue references: `Closes #N`
- Skip body entirely when the subject + diff are self-explanatory

Examples:

```
sponsor_events: wrap asset file update in transaction

Prevent data loss when replacing a hero image and the subsequent
update fails validation. The old asset file destroy is now rolled
back if the event update doesn't succeed.
```

```
SponsorEventsController#destroy: avoid double-save on withdraw

withdrawn! saves immediately, creating one editing history record,
then save! creates a second one with no meaningful diff. The job
was enqueued with the second history, missing the status change
and skipping YAML regeneration.
```

## Pull Request Titles and Descriptions

Apply the same subject line conventions to PR titles (under 70 chars).

- **Single-commit branch**: use the commit subject as title and commit body as description
- **Multi-commit branch**: write a concise summary title, then explain individual commits under headings or bullet points using Markdown

Never include test procedures, test plans, QA checklists, task lists, or TODO checkboxes in PR descriptions.
