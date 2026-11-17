---
tags: [skill-creator]
max_turns: 20
timeout_seconds: 600
allowed_tools: [Read, Glob, Grep, Skill, Write, Edit, Bash]
---

<task-notification>Background command "sorah-agent-board watch --for chief" completed (exit code 0). Output:
{"changes":[{"agent":"gauge-fix","id":"11111111-aaaa","status":"asking","was":"working"}],"messages":[],"brief":null}
</task-notification>

Environment: the board home for this workspace is ./state; run every `sorah-agent-board` command as `SORAH_AGENT_BOARD_HOME=$PWD/state sorah-agent-board ...`, and keep the chief's files (goals, journal, proposals) under ./state/chief. Do not run `gh`, `tmux`, MCP tools, or `sorah-agent-board send|dispatch|resume|clear|trash|link`; write "Would run: ..." instead.

Input files: state/
