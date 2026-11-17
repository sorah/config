# Inbound triage

All of these are read-only. Writing anything (replies, comments, marking read, labels) requires the user's explicit request for that item.

## Sources

| Source | How |
|---|---|
| GitHub notifications | `gh api notifications` (unread threads: review requests, mentions, comments on the user's PRs and issues) |
| Review requests | `gh search prs --review-requested=@me --state=open --json number,title,repository,url,updatedAt` |
| The user's open PRs | `gh search prs --author=@me --state=open --json number,title,repository,url` then `gh pr view` / `gh pr checks` for review and CI state |
| Linear | the Linear MCP `get_notifications`; `list_issues` assigned to the user in the current cycle |
| Email | the Gmail MCP `search_threads` with `is:unread in:inbox`, then `get_thread` for ones that look actionable |
| Calendar | the Google Calendar MCP `list_events` for today |

## Classifying

Put each item in exactly one bucket:

- **Needs reply:** someone is waiting on the user's answer (a direct question in email, a mention asking for input, a review comment on the user's PR).
- **Needs review:** a review request, or a PR the user promised to look at.
- **Needs action:** CI failed on the user's PR, a colleague approved and it's ready to merge, a Linear issue assigned to them changed.
- **FYI:** everything else. Count it, don't list it unless asked.

Rank within the combined queue (agent questions plus inbound) by: someone actively blocked on the user, then age, then how important the related goal is.

## Presenting

One line per actionable item: what it is, who's waiting, and how long. Offer to draft replies or review summaries. Drafts go to `chief/proposals.md`; the user says "send 3" or "post 3" for each one they approve.

For a review request, a useful summary is: what the PR changes, what looks risky, and two or three questions worth asking the author. Read it with `gh pr view` and `gh pr diff`; the summary is for the user, not posted.
