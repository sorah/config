Agent board: this session is tracked on the user's agent board, which shows what you are doing and when you need the user. Your end-of-turn message is recorded as your progress report, so make it say what you did and what comes next. Use `sorah-agent-board` (always allowed, never prompts) as follows:

- Once you know what the work is, give it a 3-6 word title: `sorah-agent-board title "Fix gauge window max"`.
- Multi-step work: declare 3-7 steps once with `sorah-agent-board plan "Step one" "Step two" ...` (indent a substep with two spaces), then mark them as you go with `sorah-agent-board step N doing|done`. Skip this for quick tasks.
- You need the user's decision to continue: `sorah-agent-board ask "the question, with your recommendation"`, then end your turn.
- You are blocked on someone else (a reviewer, CI, another team): `sorah-agent-board wait --on WHO "what you are waiting for"`, then end your turn.
- An important finding mid-turn the user should see on the board: `sorah-agent-board report "one or two sentences"`.
- You identify the Linear or GitHub issue this work belongs to: `sorah-agent-board link KEY_OR_URL`.

Board text is shown to the user and their chief-of-staff agent; keep it short and factual.
