# Report template

Every message that reports on efforts (wake-ups, briefs, "where was I", status questions) uses this one layout. The user scans it by position. If sections, field order or wording change from message to message, they have to read everything again, so keep the structure identical every time.

```
▶ answer gauge-fix: keep old metric 1 release or drop?

NEEDS YOU
  gauge-fix     WEB-420  #7612  Q: keep old metric 1 release or drop?  25m
                take: keep 1 release; panels keep working
  flaky-tests   WEB-430  #1293  done: per-worker tmp dir, CI green ×3   2m
WAITING
  rate-limiter  WEB-377  #1277  on sam: review                          1d
WORKING
  review-7598   —        #7598  step 3/5: reading handlers             12m
LEFT OFF
  tls-rotation  OPS-61   —      next: automate renewal cron             3d
GOALS   1/3  ☐ gauge PR  ☐ CI flakes  ☑ priya review
INBOX   2 reviews · 1 mention · 3 emails need reply
DRAFTS  #4 WEB-430 → In Review  (post 4)
```

## Rules

- **First line:** `▶` and the single thing to do now, or `▶ nothing needs you`.
- **Section order is fixed:** NEEDS YOU, WAITING, WORKING, LEFT OFF, GOALS, INBOX, DRAFTS. Leave out empty sections; never add others.
- **Effort lines:** exactly one per effort: name, issue, PR, what, age, in that order, columns aligned, `—` for a missing reference. Keep the line within about 72 characters.
- **What field:** starts with a fixed word for its kind:
  - `Q:` a question for the user
  - `dialog:` a permission, plan or question dialog to answer in the pane
  - `done:` a finished turn
  - `error:` a failed turn
  - `on WHO:` waiting on someone else
  - `step i/n:` working, with a declared plan
  - `next:` parked or idle, with the next step
- **Age:** how long the effort has been in its current state.
- **NEEDS YOU order:** oldest first.
- **`take:` line:** at most one per NEEDS YOU effort, indented under it, only for `Q:` items. It holds your recommendation.
- **Wake-ups:** list only the efforts that changed, then end with `· N unchanged`. Include GOALS, INBOX and DRAFTS only when they changed.
- **Briefs and "where was I":** use every non-empty section. A brief may add one line before the template: `Focus 09:30–13:00 (standup 13:00)`.
- **Formatting:** no prose paragraphs, bold, or extra headings. Wrap the block in a code fence so the columns stay aligned.
- **Detail:** give detail only when asked ("more gauge-fix"). Then answer for that one effort in at most five lines, and end with how to act (reply to relay; pane `work:gauge-fix`).
- **Inbound items:** someone waiting on a reply or review goes in NEEDS YOU as an effort line. The name is the source and the person (`gh:sam`, `mail:dana`, `slack:priya`); the reference is the PR or issue. The INBOX line only counts the rest.
- **Dialogs:** add the lane, e.g. `dialog: Bash git push (pane work:limit)`. The user answers there, via `prefix b` then `g`.
