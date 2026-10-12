# Slice Agent Prompt

This is the template for the agent that takes one slice from `# typed: false` to `# typed: strict`. Fill in the `<...>` placeholders, then delete any section that does not apply, such as the database or gem notes. Launch every slice in one message, in the background.

The template has grown from the prompts of the original rollout. When a running agent settles something new, add it under SETTLED PATTERNS for the agents that launch later, and send it to the agents still running.

````text
You are typing one slice of the <repo> codebase with Sorbet, from `# typed: false` to `# typed: strict`, writing real inline RBS signatures. Load the `sorah-guides:sorbet` skill first and follow it; it is the authority on how types are written. Then read `docs/type-checking.md`, and <domain docs for this slice>.

SLICE: <slice name>
WORKTREE (work ONLY inside this path): <absolute worktree path>
It is a git worktree on branch `<key>/<slice>`. Do NOT switch branches, rebase, merge, or push. Do NOT touch any other directory or worktree. Your shell's working directory can reset between commands, so start every command with `cd <absolute worktree path>/<project> &&`.

YOUR FILES: `tmp/slice.txt` at the worktree root lists one repo-relative path per line. Change ONLY those files, plus `<project>/sorbet/rbi/shims/*.rbi` where a gem genuinely lacks a signature. Never `git add -A`; stage your files by name.

ENVIRONMENT: every command that runs `bundle` must begin with `eval "$(mise env -s bash 2>/dev/null)";`. Without it bundler cannot resolve `sorbet-static`. Run `bundle exec srb tc` from `<worktree>/<project>`.

LOOP
1. `bundle exec spoom srb bump --from false --to true --only tmp/slice.txt` (paths relative to the project). If it reports "No files to bump" for files that do pass, edit the sigil by hand.
2. `bundle exec srb tc`. Fix what it reports in files that stayed behind, bump again, and repeat until every file in the slice is at `true`. Commit: `typing: <scope>`.
3. Change every slice file to `# typed: strict`. Run `bundle exec srb tc` and write a signature on every method, constant and instance variable until it reports `No errors!`. Commit: `typing: <scope> to typed: strict`.

HOW TO ANNOTATE: inline RBS comments only.
- Never write `sig` blocks, `extend T::Sig`, `T.let`, `T.must`, `T.cast`, or require `sorbet-runtime` in a `.rb` file. Inside a `.rbi` shim, `sig` blocks are correct.
- Never run `srb tc -a`: its autocorrect produces the forbidden forms.
- Never write `#: as !nil` or `#: as SomeMember` on a union. Use the order in the sorbet skill: restructure, narrowed local, raising reader with a `_maybe` sibling, `Must.because`, `Must.expect`, `Must.be_a`, `else x #: absurd`.
- Never add a parameter just to carry a narrowed copy of state the method can already reach (its own instance variable, a reader, or data inside an argument). Unwrap in place with a raising reader or `Must.because`.

QUALITY BAR: this is the entire point of the change.
- Write the real argument and return types. Read each method body and grep its call sites to determine them.
- Do NOT paper over a parameter with `untyped` to silence an error. `untyped` is acceptable only where the value is genuinely heterogeneous (parsed JSON, a value-or-callable, `**options` forwarded to a dependency) and you can state why.
- <For a library slice: these signatures are the public contract consumed by other apps; get them right. Give a back-compat alias the same signature as its target.>

RUNTIME BEHAVIOUR: the two commits above are annotations only. The allowed mechanical exceptions are:
- naming an anonymous `&block` or splat;
- splitting a multi-name `attr_reader` or a multiple assignment;
- reordering keyword parameters to satisfy 5049 (positional parameters stay in place);
- declaring step-filled instance variables in `initialize` as `= nil #: T?`.

Anything that changes behaviour goes in a third commit, `<scope>: <what changed>`. That covers adding `else raise`, a raising reader, `Must`, or a gate. Keep it small, and add or adjust specs for it. If a file cannot reach `strict` without restructuring public API or logic, leave it at `true` and report it instead.

SUSPECTED BUGS: if typing reveals a real bug (a nil that can actually reach a dereference, a gate that lets the wrong credential through, a constructor receiving the wrong shape), do NOT fix it inside an annotation commit. Report it with file:line and why.

SETTLED PATTERNS: follow these, do not re-litigate:
- `Data.define` readers go in `<project>/sorbet/rbi/shims/data_define.rbi` with `sig` blocks, under the header comment that is already there. Create the file if it is absent.
- A spec file with `Class.new do def initialize` or `def self.name` corrupts global resolution. If one blocks you, report it rather than editing specs.
- <conventions settled during this run>

<Shared database: DO NOT RUN RSPEC. Sibling agents share one test database and concurrent runs corrupt each other. The orchestrator runs specs after integration.>
<Otherwise: run the specs covering your files (`bundle exec rspec <dirs>`), once, at the end.>

VERIFY: from the worktree root run `hk check` (or the project's lint command). Never use `--no-verify`. <If step X fails in a fresh worktree, run Y first.> Then check `git status`, because the hk stash can resurrect deleted files.

COMMITS: follow the comment rules in CLAUDE.md. A body appears only when there is something a reader cannot get from the diff: a shim and why tapioca misses the method, a file left at `true` and the Sorbet limitation behind it, an `untyped` or widened parameter and why. End each commit with:

    Refs <key>

    Co-Authored-By: <model attribution line from your system prompt>

REPORT BACK:
- the commit SHAs
- the count of files at strict / true / false
- each holdout with its reason
- every shim edit
- every `untyped` or widened parameter
- any code change beyond the allowed mechanical ones
- suspected bugs
- anything you could not verify
````
