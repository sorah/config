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

Append only through `sorah-agent-board journal "TEXT"`; it adds the time and picks the workday file. Edit `goals.md` and `proposals.md` with the Edit/Write tools; your settings don't allow shell writes to these files.

Named by `workday` from `chief/day.json`. The workday runs 05:00 to 05:00, so late-night work stays in the same file. One line per event, oldest first, local time:

```
09:41 gauge-fix — asked: keep old metric one release? (brought to user)
09:52 gauge-fix — user: keep one release (sent)
10:05 brief — start
10:30 tls-rotation — parked; next step "automate renewal cron"
11:05 inbox — 2 review requests (webapp#7598 sam, infra#88 priya)
```

## chief/proposals.md

Each proposal has a stable number. Never reuse or renumber: the next proposal takes the highest number ever used plus one, so "post 3" always means the same thing.

```markdown
1. [x] Create issue in WEB: "Flaky integration tests in CI" (posted 11:20 on request)
2. [ ] Comment on WEB-377: "Design agreed; implementation in #1277"
3. [ ] Linear WEB-420 → In Review (PR webapp#7612 ready)
4. [-] WEB-412 → Done (dropped by user)
```

`[x]` posted, `[-]` dropped by the user. Once a day, move items that have been `[x]` or `[-]` for over a week to `chief/proposals-archive.md`, keeping their numbers.

## cache/issues/<KEY>.json

The filename is the issue key with `/` and `#` replaced by `_` (`WEB-420.json`, `acme_webapp_123.json`).

```json
{"title": "Gauge reports last sample instead of window max", "summary": "Dashboards read the gauge as a window max; it currently reports the last sample. Fix the aggregation and keep the old metric for one release."}
```

Agents receive `summary` cut at 600 characters, so put the problem, the agreed approach and constraints first. An agent already linked to the issue receives it only after `link --agent AGENT KEY` is run again.

## chief/day.json (written by the board)

`{"workday": "2026-11-18", "first_activity_at": "...", "briefs": {"start": "...", "followup": "..."}}`. Read-only for you.
