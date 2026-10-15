---
name: english-text
description: This skill should be used when writing English text on behalf of the user, such as GitHub issue/PR descriptions, code review comments, replies to maintainers or contributors, commit message bodies, business emails, or when the user asks to "write in English", "draft a reply", "write a PR description", "file an issue upstream", or "reply to this email". Provides register, phrasing, punctuation, and formatting conventions derived from the author's own GitHub activity, commits, and emails.
version: 0.1.0
---

# English Text

Conventions for writing English in the author's voice. Derived from the author's GitHub comments and PR bodies (2018–2025), git commit messages (2012–2026), and English business emails from the RubyKaigi sponsorship desk (2018–2026). Context-specific conventions always take priority.

The author is a non-native English writer whose voice is terse, direct, and technical. Reproduce the voice, not the mistakes: write grammatical English with the same rhythm and economy.

Related skills:

- Commit subject lines and prefixes: /sorah-guides:commit-style
- RubyKaigi sponsor broadcasts, portal text, terminology: rubykaigi-english-writing and rubykaigi-glossary (rubykaigi-comms plugin). This skill covers the general voice underneath them.

## Writing Contexts & Register

Identify the context before writing. Register scales with audience distance:

- **Own or team repositories** (PR bodies, issues, review comments): terse fragments, lowercase sentence start allowed, link-first, trailer-style references. A body may be a single line or a bare URL.
- **Upstream / third-party projects** (issues, PRs to projects the author doesn't maintain): capitalised full sentences, problem first then reason, cite specs/RFCs/upstream issues. `## Description` / `## Verification` headings only for long PRs, or fill the project's issue template.
- **Maintainer replies on own projects** (to users and contributors): short and decisive. Decline plainly with a reason and state what would be accepted.
- **Code review**: often just a ```` ```suggestion ```` block, or a one-line question or claim with a hedge on technical correctness.
- **Commit bodies**: usually absent. When present, one clause continuing the subject, or a short cause → effect explanation. See "Commit Bodies" below.
- **Business email** (sponsors, vendors, partners): answer-first, short paragraphs, firm on policy, warm in small doses. See `references/email.md`.

When the language choice is ambiguous (e.g. a Japanese-community repo), check surrounding comments; Japanese-community reviews are often written in Japanese even when the PR body is English.

## Openers & Closers

- No greeting on GitHub. Start with the substance, an @mention, or a link.
- Email: no greeting for quick replies; `Hi,` (no name) as default; `Hi <Name>,` with an established individual contact; `Hello,` for bad news, policy refusals, or delayed replies; `Hello <Name>,` on formal first contact. Never `Dear <Name>,` in a 1:1 reply.
- Self-introduction only on first contact: `This is Sorah from Team RubyKaigi.`
- Closers are optional. At most one short thanks: `Thanks!`, `Thank you!`, `Looking forward to it!`. Email may close with `Thanks,` / `Best,` / `Cheers,` or one warm sentence (`Thanks as always for your continued support!`).
- No signature or name on GitHub. No `LGTM`; approve with nothing, or `✅` plus what was verified.

## Vocabulary & Phrasing

- Hedges on technical claims: `I believe`, `I think`, `I guess`, `Looks like`, `seems`, `perhaps`, `maybe`, `I wonder if`, `if I read the RFC correctly`, `honestly I don't know`.
- Abbreviations used naturally on GitHub: IIRC, AFAIK, OTOH, e.g., i.e., w/o, dupe, PR, CI. Keep them out of business email and commit bodies.
- Stock phrases: `at this moment`, `it should be okay`, `For instance,`, `From my perspective,`, `Also,`, `Therefore`, `This allows …`, `Previously …`, `now …`.
- Requests: `Could you …?`, `could you take a look at this please?`, `feel free to …`, `Please let us know …`, `I'd suggest …`, `I'd request you to …` (email). Plain imperatives with familiar maintainers (`@maintainer consider merging this`). Never `Would you mind …`.
- Acknowledgements (email): `Noted.`, `Understood,`, `Affirm.`, `True.`, `Thanks, confirmed the payment!`, `Thank you for the patience.`
- Disagreement stated head-on, then reason, then alternative: `I disagree with this direction. … I'd suggest a new resource to cover X instead.`
- Firm statements use uncontracted forms (`I am not going to`, `I do not recommend`); everything else uses contractions.
- Apologies: one clause with the cause, then straight back to business (`Sorry for the late reply due to Japanese bank holidays.`, `Oops, sorry I didn't notice this PR for a long time.`). Never a standalone apology paragraph.
- Mild dry humour and exasperation are fine in short form: `(why?)`, `What??`, `Sounds fancy.`, `The method signature is weird!`. No swearing.

## Sentence Structure

- Answer or conclusion first, then the reason. A reason usually follows as `because …`, `to …`, `otherwise …`, `so …`, `due to …`.
- Fragments without a subject are normal in quick replies and own-repo text: `Yes, correct.`, `Still confirming with my colleague.`, `manually tested and confirmed: …`, `should be fixed in 2.7.1, thanks`.
- Parenthetical asides are frequent and carry scope notes, caveats, and side remarks: `(tax excl.)`, `(to be confirmed)`, `(Note: prior to Git v2.32.0, …)`.
- Trailing `...` for a sigh or afterthought, sparingly: `currently meaningless...`, `Oops, it didn't work...`.
- `a -> b` or `a => b` for renames, version bumps, and transitions.
- Keep sentences short and declarative. No hedge stacking, no build-up to a point.

## Punctuation & Orthography

- No em dashes in GitHub text or commits. Use a spaced hyphen (` - `), parentheses, a semicolon, a colon, or a new sentence. In email body text, prefer the same; reserve `—` for the signature separator.
- Semicolons are acceptable as a clause joiner.
- Lowercase sentence starts are acceptable in casual own-repo GitHub text and commit bodies. Capitalise in upstream prose and in all email.
- Commit subjects have no trailing period; one-clause commit bodies usually omit it too.
- British spelling with -ise endings: behaviour, colour, organise, finalise, utilise, licence (noun), programme (non-software), travelling, cancelled. Do not mix within one text.
- Keep identifiers, API names, CLI flags, and quoted upstream text in their original spelling (`initialize`, `color:`, `--authorize`).
- Dates: `DD MMM YYYY` (`12 Mar 2026`), or `DD MMM` (`12 Mar`) when the year is obvious. Append the weekday in parentheses when it helps (`21 Apr (Tue)`). No ordinals, no commas, no month-first or numeric forms (`3/12`, `2026-03-12`) in prose.
- Email formats: Japan time marked `JST`; 24-hour times in notices (`17:00`); money as `25,500 JPY (tax excl.)`; UI labels in square brackets (`[Re-assign]`).

## Markdown

- Backticks for identifiers, commands, flags, and values.
- Fenced code blocks with a language; 4-space indented blocks for pasted error output or shell transcripts.
- `>` to quote the exact line being answered, or spec text being cited.
- Bare URLs as references, often as the first or only line. Inline links for named things; reference-style links for specs (`[SEC1]: https://…`). `See also: <url>`.
- Short bullet lists with `-`, nested two spaces, for "why" notes in PR bodies.
- Avoid bold and headings in short PRs, comments, and 1:1 emails. Task lists and `<details>` only when an issue template demands them.

## Composition

### PR bodies

Own/team repos: optional one-line reason, then reference lines.

```
for better backend latency

https://github.com/ruby-no-kai/rko-router/issues/81
```

Reference trailers: `Closes #N`, `Fixes #N`, `Needs owner/repo#N`, `follow-up: <sha or url>`, `bug: <url>`. Use full SHAs.

Upstream: state current behaviour, why it is a problem, what the change does, with spec citations. Paragraphs, not a `## Summary` / `## Test plan` template.

### Commit bodies

- Omit the body for routine changes.
- Typical body: one lowercase clause continuing the subject (`because we do chdir.`, `otherwise fails when more than 2 routers exist in the same VPC`).
- A bare upstream URL alone is a valid body.
- Longer bodies only for genuinely tricky mechanisms: mechanism → why it breaks → what the change does → caveat (`Also, …`). Impersonal voice; `we` for the project.
- Wrap at 72 columns.
- Release commits: `= New features`, `= Enhancements`, `= Bug fixes`, `= Breaking changes` sections with terse bullets and `(#N, @user)` credits.

### Maintainer replies

Verdict → reason → what would be accepted. `IIRC some secret providers don't support return characters, so I am not going to directly support this.` / `PRs are always welcome and I'm positive for this feature. Looking forward to it!`

### Emails

Lead with the answer. For multiple questions, answer per item: `>`-quote then answer, `Topic: answer` lines, or numbered answers mirroring the sender's numbering. Refusals: verdict → policy or physical reason (cite the document) → optional alternative → one-line thanks. Details and examples in `references/email.md`.

## Reproduce the Voice, Not the Slips

The corpus contains recurring non-native errors. Do not imitate them:

- Articles: write `a user`, `an empty Proc`, `for a long time`, `in the past`, `in late 2024`, `Thank you for the proposal`.
- Verb patterns: `makes X spawn` (not `makes X to spawn`), `would help prevent`, `I do not recommend using`, `I disagree with`, `take a look at it`, `Why did you put …?`, `subject to`.
- Agreement: `these methods generate`, `2 routers exist`, `the information is attached`.
- Uncountables: `information`, `advice`, `software`, `pricing`, `stuff` (never pluralised).
- Doubled conjunctions: not `While I agree …, but …`.
- Calques: not `as like as`, `forcely`, `samely`; write `as we did before`, `forcibly`, `the same as`.
- Spelling: occurred, suppress, accommodate, consider, colleagues, attendees.

## What NOT to Do

- No pleasantries: `I hope this finds you well`, `Hope you're doing well`, `Great question`, `Happy to help`, `Please don't hesitate to contact us`, `Should you have any questions`.
- Prefer `Thanks,` / `Best,` / `Cheers,` over `Best regards` / `Kind regards`; never `Sincerely`.
- No restating the other party's request before answering; quote it with `>` instead.
- No multi-sentence apologies, no over-thanking, no marketing tone or superlatives.
- No `## Summary` / `## Test plan` boilerplate, no "This PR …" / "This commit …" openers, no essay-style change narration.
- No em dashes, no bold emphasis in prose, no 🎉 / 🚀. Emoji only as functional markers: ✅ verified/done, ♻️ addressed/updated, 🙏 polite decline, 😫 own mistake.
- No unexplained "no": every refusal carries a reason.
- Don't over-explain what the audience already knows; link instead.

## Additional Resources

- **`references/github.md`** — verbatim examples by GitHub context (own-repo PRs, upstream issues/PRs, maintainer replies, reviews, nudges) and commit bodies
- **`references/email.md`** — business email structure, phrase palette, refusal and reminder patterns, subject lines
