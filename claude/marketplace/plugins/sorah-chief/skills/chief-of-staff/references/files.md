# Chief files

All under `${XDG_STATE_HOME:-~/.local/state}/sorah-agent-board/`.

## chief/goals.md

```markdown
# Week of 2026-11-16
- Ship the gauge fix (WEB-420)
- Rate limiter design agreed with sam (WEB-377)

# 2026-11-18
- [ ] Get #7612 out of draft
- [x] Review webapp#7598
```

Check items off as the journal shows them done; ask before removing a goal.

## chief/journal/YYYY-MM-DD.md

One line per event, oldest first, local time:

```
09:41 gauge-fix — asked: keep old metric one release? (relayed to user)
09:52 gauge-fix — user: keep one release (sent)
10:30 tls-rotation — parked; next step "automate renewal cron"
11:05 inbox — 2 review requests (webapp#7598 sam, infra#88 priya)
```

## chief/proposals.md

```markdown
1. [ ] Linear WEB-420 → In Review (PR webapp#7612 ready)
2. [ ] Comment on WEB-377: "Design agreed; implementation in #1277"
3. [x] Create issue in WEB: "Flaky integration tests in CI" (posted 11:20 on request)
```

## cache/issues/<KEY>.json

The filename is the issue key with `/` and `#` replaced by `_` (`WEB-420.json`, `acme_webapp_123.json`).

```json
{"title": "Gauge reports last sample instead of window max", "summary": "Dashboards read the gauge as a window max; it currently reports the last sample. Fix the aggregation and keep the old metric for one release."}
```

Keep `summary` under about 600 characters: the problem, the agreed approach, and constraints. Agents receive it when they're linked to the issue.

## chief/day.json (written by the board)

`{"workday": "2026-11-18", "first_activity_at": "...", "briefs": {"start": "...", "followup": "..."}}`. Read-only for you.
