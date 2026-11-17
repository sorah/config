# Chief files

All under `${XDG_STATE_HOME:-~/.local/state}/sorah-agent-board/` (or `$SORAH_AGENT_BOARD_HOME`).

## chief/goals.md

```markdown
# Week of 2026-11-16
- Ship the gauge fix (WEB-420)
- Rate limiter design agreed with sam (WEB-377)

# 2026-11-18
- [ ] Get #7612 out of draft
- [x] Review webapp#7598
```

Check items off as the journal shows them done; ask before removing a goal. Drop sections older than two weeks.

## chief/journal/<workday>.md

Append only through `sorah-agent-board journal "TEXT"`; it adds the time and picks the workday file. Edit `goals.md` with the Edit/Write tools; your settings don't allow shell writes to it. Decisions, drafts and suggestions live in `attention.json`, managed only through `sorah-agent-board attention`.

Named by `workday` from `chief/day.json`. The workday runs 05:00 to 05:00, so late-night work stays in the same file. One line per event, oldest first, local time:

```
09:41 gauge-fix — asked: keep old metric one release? (brought to user)
09:52 gauge-fix — user: keep one release (sent)
10:05 brief — start
10:30 tls-rotation — parked; next step "automate renewal cron"
11:05 inbox — 2 review requests (webapp#7598 sam, infra#88 priya)
```

## cache/issues/<KEY>.json

The filename is the issue key with `/` and `#` replaced by `_` (`WEB-420.json`, `acme_webapp_123.json`).

```json
{"title": "Gauge reports last sample instead of window max", "summary": "Dashboards read the gauge as a window max; it currently reports the last sample. Fix the aggregation and keep the old metric for one release."}
```

Agents receive `summary` cut at 600 characters, so put the problem, the agreed approach and constraints first. An agent already linked to the issue receives it only after `link --agent AGENT KEY` is run again.

## chief/day.json (written by the board)

`{"workday": "2026-11-18", "first_activity_at": "...", "briefs": {"start": "...", "followup": "..."}}`. Read-only for you.
