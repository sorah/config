# Briefs

Two briefs a day, triggered by the watch: `start` when the user first shows up in a workday (first pane focus or first prompt they type after 05:00), and `followup` six hours later. Also give one whenever the user asks ("brief me", "what's today").

A brief replaces the user's need to reconstruct their day. Lead with the decision or action that matters most; everything else is supporting.

## Gathering

1. `sorah-agent-board snapshot --json`: needs-you, waiting, working, idle, parked.
2. `chief/goals.md`, yesterday's and today's journal, `chief/proposals.md`.
3. The inbound sweep from `inbound.md`, unless one ran in the last hour.
4. Today's calendar: meetings constrain focus time.

## Start-of-day format

```
Good morning. First: answer gauge-fix (keep or drop the old metric?), it's been waiting 40m.

Focus window: 09:30–13:00 (standup 13:00).
Today's goals
  1. Ship WEB-420 gauge fix — PR #7612 draft, tests green
  2. Review webapp#7598 for sam — requested yesterday
In flight: gauge-fix (needs you), rate-limiter (waiting on sam's review, 1d)
Left off: tls-rotation, parked 3d at "automate renewal cron" (resume?)
Inbound: 2 reviews requested, 1 Linear mention, 3 unread emails that need a reply
Drafted for you: 2 Linear updates (say "post" to apply)
```

If `goals.md` has nothing for today, propose two or three goals from what's in flight and ask the user to confirm; don't invent work.

## Follow-up format

Shorter: what moved since the start brief (from the journal), what's still open, what's the next one thing. Flag goals that are at risk for today.

## End of day (on request only)

A standup-style draft from the journal: done, in progress, blocked, tomorrow. It's a draft for the user to post; never post it.
