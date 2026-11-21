# Agent board and chief of staff

A board of every Claude Code agent running in tmux on this machine, and a long-running "chief of staff" Claude session that keeps those agents answered, keeps work traceable to Linear and GitHub, and remembers what the user was doing. It works over SSH without Claude Code desktop or herdr.

## Constraints

These shaped the design; keep them when changing it.

- **No screen scraping.** State comes only from Claude Code hooks, never `tmux capture-pane`. An Esc interrupt fires no hook, so a working agent with no events for 10 minutes is shown as stale.
- **The chief never posts on the user's behalf** (Linear, GitHub, Slack, email, calendar: comments, state changes, new issues, mark-read) unless the user asks for that specific action. It drafts instead, as numbered attention items the user approves by number.
- **Agents' questions go to the user.** The chief may give an agent only factual context: the issue it belongs to and a brief of it.
- **Nothing is garbage-collected.** Ended or abandoned sessions become "parked" and stay on the board with their history until the user archives them.
- **External content is untrusted**, colleagues' messages included, and more so when the chief runs unattended. It is read through quarantined summaries (see Isolation).
- **The user's tmux behaviour is unchanged.** The chief is an extra session on the user's own server, added only when that server exists; zsh's auto-attach is untouched.
- **Portable.** Code and config live in `~/git/config`; runtime state is per machine.

## Layout

```
bin/sorah-agent-board                  CLI entry (Ruby, stdlib only, --disable-gems)
claude/agent-board/
  lib/agent_board/                     library (below)
  agent-protocol.md                    injected into every agent at SessionStart
  chief-settings.json                  the chief's --settings: plugin, permissions, guard hooks
  chief-policy.json                    guard decision table for the chief
  tui/                                 Bun + TypeScript + Ink board
  test/                                minitest
claude/settings.jsonnet                hook groups `_id: 'agent-board'`, Bash(sorah-agent-board:*) allow
claude/marketplace/plugins/sorah-chief/ the chief's operating manual (skill chief-of-staff) and evals
tmux/tmux.conf                         key bindings, status count, focus hook
mise.toml                              systemd user unit for the supervisor
```

Runtime state is in `${XDG_STATE_HOME:-~/.local/state}/sorah-agent-board/` (or `$SORAH_AGENT_BOARD_HOME`):

| Path | Contents |
| --- | --- |
| `sessions/<id>.json` | One record per Claude session (`Session` struct) |
| `events/<id>.jsonl` | Append-only timeline per session |
| `archive/` | Sessions the user archived; `unarchive` restores them |
| `locks/` | flock files (per session, summary, attention, watch) |
| `cache/` | PR facts, issue briefs (`issues/<KEY>.json`), session names, learned Linear team keys |
| `inbox/chief/` | Messages from agents to the chief (`tell chief`) |
| `intake/items.json` | Quarantined inbound records |
| `chief/` | Chief memory: `goals.md`, `journal/<workday>.md`, `attention.json`, `presence.json`, `day.json`, `supervisor.json`, `watch-cursor.json`. Also the chief's working directory |
| `hook-errors.log` | stderr of the hook; the hook itself always exits 0 |

## Library

| File | Role |
| --- | --- |
| `hook.rb` | Reads a hook payload from stdin, runs it through `State`, persists via `Store`. On SessionStart, fills cwd, transcript, tmux socket/pane/lane, repo, branch, writes `SORAH_AGENT_BOARD_SESSION` to `CLAUDE_ENV_FILE`, and returns `agent-protocol.md` and issue context as `additionalContext`. Backfills tmux/cwd on the first event of sessions that skipped SessionStart. Parks the previous session in the same pane. Spawns the summarizer on Stop. |
| `state.rb` | Pure state machine from hook events to session fields and timeline events. Records live activity (PreToolUse), milestones from Bash (`git commit` subject, `gh pr create` URL, failed test commands), and issue links. |
| `session.rb` | The session record and its derived `status`: parked > error > blocked > asking > waiting > working > done (unseen) > idle. |
| `store.rb` | State directory, per-session flock, atomic writes, timeline, archive, workday (05:00 boundary), user activity. |
| `issue_ref.rb` | Linear/GitHub reference parsing and `attach`, which decides the primary issue. Explicit, dispatch and chief links are pinned; a Linear issue replaces a non-pinned GitHub primary. |
| `session_name.rb` | Reads the `/rename` (`custom-title`) or `--name` (`agent-name`) record from the transcript incrementally. |
| `summarizer.rb` | Background `claude -p` (Haiku, no tools, no settings, JSON schema) condensing each end-of-turn report into did / now / decide, plus a title when the work has none. |
| `recap.rb` | Timeline recap: outcomes and the user's real inputs (first prompt, answers), not every prompt. |
| `snapshot.rb` | Render-ready grouped view (needs you, waiting, working, idle, parked), labels, issue column (one Linear and one GitHub ref), PR facts (`pull_requests.rb`, cached `gh`), attention items. Mirrored by `tui/src/snapshot.ts`. |
| `watch.rb` | `watch --json` streams snapshots to the TUI; `watch --for chief` blocks until something worth the chief's attention, then exits. |
| `relay.rb` | `send`: bracketed paste into an agent's pane, refused while a dialog is open or the agent is not at its prompt, confirmed by the agent's next UserPromptSubmit within 5 s. |
| `chief.rb` | Chief lifecycle (`ensure_running`, `supervise`, daily fresh start), `Dispatch` of new agents, `ChiefWatch` and brief triggers. |
| `attention.rb` | The chief's FROM CHIEF list: `decide`, `draft`, `suggest` items with never-reused numbers. |
| `presence.rb` | Whether the user is at the chief (messaged it within 15 minutes), and whether a CLI caller is the chief (process ancestry env). |
| `guard.rb` | The chief's PreToolUse/PostToolUse hook enforcing `chief-policy.json`. |
| `intake.rb` | Inbound sweep: GitHub parsed deterministically; Linear, Slack, Gmail and Calendar through quarantined readers. |
| `text.rb` | Sanitising (control, bidi and zero-width characters, URLs), markdown to plain text, briefs. |
| `tmux.rb` | Per-socket tmux queries (pane IDs are unique only per server). |
| `cli.rb` | Subcommands; `sorah-agent-board help` lists them. |

## Agents

Every Claude Code session gets the hooks from `claude/settings.jsonnet` for SessionStart, UserPromptSubmit, PreToolUse, PostToolUse, PostToolUseFailure, PermissionRequest, PermissionDenied, Elicitation, ElicitationResult, Notification, SubagentStart, Stop, StopFailure and SessionEnd. The hook is about 70 ms, never touches the network, and always exits 0.

`agent-protocol.md` asks agents to cooperate through the CLI, which is allowlisted so it never prompts: `title`, `plan`/`step` for multi-step work, `ask` when they need the user, `wait --on` when blocked on someone else, `report`, `link`. Progress does not depend on task lists: the passive sources are the end-of-turn message (Stop's `last_assistant_message`), Bash milestones, and edited-file counts.

Issue linking, first match wins: a dispatch record, the branch name, the first prompt, later signals (Linear `get_issue`, `gh issue view`, Linear URLs in reports or `gh pr|issue create|edit`), or an explicit `link`. The agent is told its issue via `additionalContext`; briefs are wrapped as `<external-content>`.

Labels on the board: an explicit board name, else the Claude session name (`/rename`), else the live tmux placement (a user-named window, the session unless numbered, the directory).

## TUI

`sorah-agent-board tui` runs `tui/src/main.tsx` with Bun (installs `node_modules` from `bun.lock` on first run; finds bun in PATH or via `mise which bun`). It only consumes `watch --json`. Bun strips types without checking them; run `bun run typecheck` in `tui/` before committing.

Rows have a flowing header (`● label · issue · title · PR · age`), then `working:` while a turn runs, `decide:` once the turn has ended, the plan bar, the did/now digest, two recap lines and a meta line. Keys: `j`/`k`, `C-f`/`C-b`, Enter to expand (PLAN, LAST REPORT, TIMELINE, FACTS), `m` more, `g` jump to the pane, `r` resume a parked session, `a` archive (confirm with `y`), `u` undo, `q` quit. FROM CHIEF at the top lists open attention items.

## Chief of staff

A Claude session named `chief-of-staff` in the tmux session `chief` on the user's default server, working in `<state>/chief/`, started as:

```
claude --name chief-of-staff --remote-control chief-of-staff --settings claude/agent-board/chief-settings.json [--resume ID] "/sorah-chief:chief-of-staff …"
```

through `zsh -lic` with `SORAH_AGENT_BOARD_NAME=chief-of-staff`, so it has the user's PATH and tools.

- **Supervisor.** `sorah-agent-board chief supervise` (systemd user unit) checks every 60 s. With no tmux server it does nothing, so a login still creates the server with the user's environment and prefix. When the chief is missing it updates the `sorah-chief` plugin (Claude Code runs an installed copy) and starts it, resuming the last chief session. At 05:00 it starts fresh; all durable memory is in files.
- **Messages in.** From the user: the pane (`prefix O`) or Remote Control from claude.ai or the phone. From the board: the chief keeps `watch --for chief` running in the background; it exits on new asks, blockers, finished turns, errors or inbox messages, which wakes the chief. From agents: `tell chief TEXT`.
- **Messages out.** To the user: the attention list (FROM CHIEF on the board, counted in the tmux status) and its pane. To agents: `send`, only to relay the user's own words, and issue briefs (`brief-issue`).
- **Memory.** `goals.md`, the per-workday journal (`journal` command), attention items. "Where was I" is answered from these, the board, and parked sessions.
- **Briefs.** When the user is first seen working on a workday, and six hours later.
- **Not the chief's job:** answering agents' questions, nudging agents, deciding for the user, posting anything unasked. An agent's own pending question already shows on its row, so `attention add decide --agent` refuses it.

The operating manual is the `chief-of-staff` skill in `sorah-chief`; its `references/` hold the report template, brief, inbound and file formats. Evals live in its `evals/`.

## Isolation and permissions

The chief's tool calls pass through `guard.rb` (PreToolUse/PostToolUse/SessionStart hooks in `chief-settings.json`; a guard failure exits 2 and blocks). Each call is classified, and the decision comes from `chief-policy.json` by the chief's state:

| Class | Absent | Present | Tainted |
| --- | --- | --- | --- |
| exfil (curl, ssh, …) | deny | deny | deny |
| store_write (direct writes to board state) | deny | deny | deny |
| external_read (raw Linear/Slack/mail/GitHub content) | deny | ask | ask |
| external_write (any post, edit, `gh api` writes, MCP writes) | deny | ask | ask |
| board_gated (`send`, `dispatch`, `archive`, `resume`, …) | deny | allow | ask |
| unparseable | deny | ask | ask |

- **Present**: the user messaged the chief within 15 minutes. **Absent** otherwise, i.e. unattended.
- **Tainted**: the session read raw external content; cleared only by a new or cleared session.
- Shell commands are split quote-aware, command substitutions included; `gh api` is classified by method, fields and GraphQL mutations; MCP tools by verb.

Unattended intake never shows raw content to the chief. `intake sweep` runs one `claude -p` per source with only that source's read tools, writes disallowed, and a strict JSON schema (category enum, ID patterns, length caps, links stripped). The chief reads only those records through `intake list`. GitHub needs no model: notifications and review requests are parsed directly.

Gated CLI commands (`send`, `dispatch`, `archive`, `resume`, `clear`, `brief-issue`) check presence themselves when the caller is the chief, so the gate holds even if a permission rule is loosened.

## tmux

In `tmux/tmux.conf`:

- `prefix b`: the board in a popup. `prefix O`: toggle to and from the chief.
- `prefix C`: new named session; `prefix X`: kill the session (on `chief`, the supervisor restarts it within a minute). `prefix C-,`: customize mode. `prefix q`: last window; `prefix Q`: pane numbers.
- status-left shows named sessions next to the hostname; status-right starts with the needs-you count (`sorah-agent-board count`).
- `pane-focus-in` runs `seen`, turning a finished turn from done to idle.
- `detach-on-destroy off`, so killing a session switches to another instead of detaching.

## Enabling on a machine

Hooks are recorded for every Claude Code session once the settings are applied; the chief is optional.

1. Have `~/git/config` checked out, Ruby, tmux, `gh` (authenticated) and `claude` on PATH. Bun comes from mise (`mise/tools.toml`) and is needed only for the TUI.
2. Apply Claude Code settings, which adds the hooks and the CLI allow rule:
   ```
   ruby ~/git/config/claude/update-settings.rb
   ```
3. Load the tmux config: `tmux source-file ~/.tmux.conf` (or restart tmux).
4. For the chief, install its plugin, disabled for normal sessions (`chief-settings.json` enables it for the chief only). `setup.sh` does this:
   ```
   claude plugin marketplace add ~/git/config   # once, if sorah-marketplace is not known yet
   claude plugin add sorah-chief@sorah-marketplace
   claude plugin disable sorah-chief@sorah-marketplace
   ```
5. Start the supervisor (Linux). The unit comes from `mise.toml` and is installed by `mise bootstrap`, but neither enabled nor started:
   ```
   systemctl --user daemon-reload
   systemctl --user enable --now dev.mise.chief-of-staff
   ```
   On macOS there is no unit; run `sorah-agent-board chief ensure` by hand or from launchd.
6. With tmux running, the chief appears within a minute. Attach once with `prefix O` and accept the folder trust dialog for `<state>/chief`. Connectors (Linear, Slack, Gmail, Calendar) come from the user's claude.ai account.

After changing the chief's skill, bump the version in `plugin.json` and `.claude-plugin/marketplace.json`, then `prefix X` on `chief`; the supervisor updates the plugin before restarting it. After changing library code, `systemctl --user restart dev.mise.chief-of-staff` so the supervisor runs it.

### Environment

| Variable | Effect |
| --- | --- |
| `SORAH_AGENT_BOARD_HOME` | State directory instead of `$XDG_STATE_HOME/sorah-agent-board` |
| `SORAH_AGENT_BOARD_DISABLE=1` | Hooks do nothing (used by the board's own `claude -p` runs) |
| `SORAH_AGENT_BOARD_DEBUG=1` | Dump raw hook payloads |
| `SORAH_AGENT_BOARD_SUMMARY_MODEL` | Summarizer model (default `haiku`) |
| `SORAH_AGENT_BOARD_INTAKE_MODEL` | Intake reader model (default Sonnet) |
| `SORAH_AGENT_BOARD_LINEAR_TEAMS` | Comma-separated Linear team keys accepted as bare `KEY-123`, in addition to learned ones |
| `SORAH_AGENT_BOARD_SESSION` | Set in agents by SessionStart; tells the CLI which session it runs in |
| `SORAH_AGENT_BOARD_NAME` | Board name of a session; `chief-of-staff` marks the chief |

## Testing

```
cd ~/git/config/claude/agent-board
ruby -Ilib -Itest -e 'Dir["test/**/*_test.rb"].each { require "./" + _1 }'
cd tui && bun run typecheck
bun run src/main.tsx --fixture fixtures/board.jsonl   # render without live state
```

## Not built yet

- The board as a claude.ai artifact, with replies from a phone.
- Approving permission dialogs from the board.
- A launchd agent for macOS.
- Correct width for CJK text in the TUI.
