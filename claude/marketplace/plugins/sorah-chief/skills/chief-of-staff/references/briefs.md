# Briefs

Two briefs a day come from the watch: `start` when the user first shows up in a workday (first pane focus or first prompt they type to an agent after 05:00), and `followup` six hours later. Also brief whenever the user asks ("brief me", "what's today"). Journal each brief (`HH:MM brief — start`), so a later trigger the same day only covers what changed.

A brief replaces the user's need to reconstruct their day. Lead with the decision or action that matters most; everything else supports it.

## Gathering

1. `sorah-agent-board snapshot --json`: needs-you, waiting, working, idle, parked.
2. `chief/goals.md`, the current and previous workday journals, `sorah-agent-board attention list`.
3. The inbound sweep from `inbound.md`, unless the journal shows one (`HH:MM inbox — …`) within the last hour.

## Format

Use the full template from `report.md`, with the optional `Focus` line first, taken from the `intake` calendar records for today. A start brief uses every non-empty section.

If `goals.md` has nothing for today, use `GOALS   none set · proposing: …` with two or three goals taken from what's in flight, and ask the user to confirm. Don't invent work.

A follow-up brief uses the same template, but lists only efforts that changed since the start brief (from the journal), then `· N unchanged`. Mark goals at risk for today with `!` in the GOALS line.

## End of day (on request only)

A standup-style draft from the journal: done, in progress, blocked, tomorrow. It is a draft for the user; post it only on their explicit request, per the ground rules.
