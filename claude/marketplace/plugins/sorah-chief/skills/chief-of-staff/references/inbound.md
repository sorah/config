# Inbound triage

All of these are read-only. Writing anything (replies, comments, marking read, labels) requires the user's explicit request for that item. Journal each sweep (`HH:MM inbox — 2 reviews, 1 mention, 3 emails`) so briefs can tell when the last one ran.

## Sources

| Source | How |
|---|---|
| GitHub notifications | `gh api notifications` (unread threads: review requests, mentions, comments on the user's PRs and issues) |
| Review requests | `gh search prs --review-requested=@me --state=open --json number,title,repository,url,updatedAt` |
| The user's open PRs | `gh search prs --author=@me --state=open --json number,title,repository,url`, then `gh pr view` / `gh pr checks` for review and CI state |
| Linear | the Linear MCP `get_notifications`; `list_issues` assigned to the user in the current cycle |
| Slack | the Slack MCP `slack_search_public_and_private` for DMs and mentions of the user since the last sweep |
| Email | the Gmail MCP `search_threads` with `is:unread in:inbox`, then `get_thread` for ones that look actionable |
| Calendar | the Google Calendar MCP `list_events` for today; meetings bound the focus window in briefs |

## Classifying

Put each item in exactly one bucket:

- **Needs reply:** someone is waiting on the user's answer (a direct question in email or Slack, a mention asking for input, a review comment on the user's PR).
- **Needs review:** a review request, or a PR the user promised to look at.
- **Needs action:** CI failed on the user's PR, a colleague approved and it's ready to merge, a Linear issue assigned to them changed.
- **FYI:** everything else. Count it; list it only if asked.

Rank the combined queue (agent questions plus inbound) by: someone actively blocked on the user, then age, then how important the related goal is.

## Presenting

One line per actionable item: what it is, who's waiting, and for how long. Offer to draft replies or review summaries. Drafts become numbered proposals; the user approves them by number.

For a review request, a useful summary covers what the PR changes, what looks risky, and two or three questions worth asking the author. Read it with `gh pr view` and `gh pr diff`; the summary is for the user and is not posted.
