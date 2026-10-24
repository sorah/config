---
name: sorbet-adoption
description: This skill should be used when introducing Sorbet static type checking to an existing Ruby or Rails application, or when continuing such a rollout. It applies when the user asks to "add type checking", "adopt Sorbet", "set up Sorbet and tapioca", "add RBS types to the codebase", "type the app gradually", "raise everything to typed: strict", or "plan typing PRs", or mentions a typing stack or issue in progress. Provides a proven rollout playbook: a repository survey, decisions to settle up front, the infra PR, sigil stamping, dependency-ordered slices as stacked PRs, parallel per-slice agents, serial integration, review, and keeping the stack current. Pair with the sorbet skill, which defines how the types themselves are written. For a Ruby library or gem, prefer Steep through the steep-adoption skill.
version: 0.1.0
---

# Sorbet Adoption

This is a playbook for bringing an untyped Ruby or Rails application to Sorbet `# typed: strict` through a series of reviewable PRs. It is distilled from a rollout that took a Rails app and its client gem from no annotations to about 300 strict files in 22 stacked PRs.

Libraries and gems use Steep instead, through `sorah-guides:steep-adoption`: RBS is what gems ship in `sig/` and what consumers load, while Sorbet suits an application that nobody depends on. A gem that lives inside an application's repository and is consumed only by that app may follow the app onto Sorbet.

Load `sorah-guides:sorbet` before writing any annotation. That skill defines how types are written. This one decides order, scope and mechanics. For branch and stack mechanics use `/gh-stack`; for commits and PR bodies use `/sorah-guides:commit` and `/sorah-guides:pull-request`.

The rollout runs in this order:

1. Survey and decide
2. Infra PR
3. Prep PRs
4. Sigils PR
5. Slices, bottom-up
6. Integrate
7. Review
8. Keep current

## Lessons that shaped this playbook

- **`typed: true` is not the goal.**
  - The first pass of the original rollout raised 17 slices to `true` and was green. Yet the code carried 6 method signatures across about 1750 methods, because `true` demands none and the exit condition was "bump and `srb tc` green".
  - Every slice had to be redone to `strict`, which surfaced over 3000 errors (about two thirds of them missing signatures).
  - Plan for `strict` from the start.
- **Casts are debt.**
  - The strict pass then left more than 250 `#: as !nil` casts, and a later pass replaced them with restructures, raising readers and `Must`.
  - Write nil and union handling the `sorbet` skill's way from the first commit.
- **Shared shims belong in the infra PR.** Slices that each added the same `logger` method or the same timestamp cast produced add/add conflicts and duplicated work. One shim at the bottom of the stack removed every copy.
- **Cross-slice errors appear only after stacking.** Slices typed in parallel are each green alone. Once chained, a single wrong return type in a low layer caused 87 errors above it. Budget an integration pass.
- **Agent output needs a real review.** Many agents writing casts in security-sensitive code surfaced real bugs: a positional `initialize` that silently received a Hash, and controllers reading `current_user` under a gate that a machine credential passes. They also produced workarounds that turned out to be unnecessary.

## Phase 0: Survey and decide

### Survey first

Survey the repository before proposing anything; the defaults below bend to what you find. Count on the current default branch: `git fetch`, then use `git ls-files` against `origin/<default>`, because a local checkout may be weeks behind.

| Check | Why it matters |
|-------|----------------|
| Size: files and methods in scope, and how fast main moves (merges and authors per month) | Sets slice count and size, and whether one deep stack can stay rebased |
| `Gemfile.lock` for `sorbet-runtime`, pulled in by a gem | If it already loads in production, a stray `sig` or `T.let` becomes a live runtime check instead of a load error. Add a CI grep that bans those forms |
| `Gemfile.lock` platforms, plus any local uncommitted lockfile change | `sorbet-static` cannot resolve with a `ruby` platform |
| Dockerfile and build context | A committed `third_party/` copied before `bundle install` invalidates that layer on every RBI change. Add a `.dockerignore` entry or pick another RBI location |
| Engines, vendored gems and submodules inside the repo | Tapioca skips gems that live in the app tree, so those are read from source. Vendored code owned elsewhere is never edited here, and needs its upstream shims copied along. A submodule needed to boot must be initialized in every agent worktree |
| ORMs and DSLs without a tapioca compiler (Dynamoid, ActiveHash, custom macros), and `time_zone_aware_attributes` | Plan custom DSL compilers or shims. With time-zone awareness off, datetime columns are typed `Time`, which clashes with `Time.current` |
| Count of non-optional `belongs_to` | A few dozen are fine with `Must.expect`. Hundreds may justify a custom tapioca compiler that types them non-nil |
| Editor tooling such as Ruby LSP | It changes behaviour once `sorbet-static` is in the bundle. Tell the team |
| Generators and templates (`lib/templates`, custom generators) | New files they produce must start at `# typed: strict` |
| How specs isolate (`TEST_ENV_NUMBER`, shared databases) | Decides whether parallel slice agents may run specs |
| Existing CI, lint and hook layout (hk, lefthook, a lint workflow) | The typecheck joins whatever already runs RuboCop |

### Decisions

Settle these with the user through AskUserQuestion. Put the recommended option first.

| Decision | Recommended default |
|----------|---------------------|
| Checker and syntax | For an application, Sorbet with inline RBS comments (`#:`). Static only: `sorbet` and `tapioca` in the development/test group with `require: false`, and no `sorbet-runtime` of the project's own. For a published gem, switch to `steep-adoption` |
| Scope | Every Ruby project in the repo, covering `app/`, `lib/`, `config/` and in-repo engines. Specs are never typed |
| Generated RBIs | Committed at `//third_party/sorbet/rbi/<project>/{gems,dsl}` and marked `linguist-generated=true`. Drop `<project>/` when there is only one project; move elsewhere if the survey shows a build-context problem |
| PR shape | One infra PR for all projects, then slices stacked on it in one straight line. Sub-projects such as a gem go on top of that line. In a busy repo where one long stack cannot stay rebased, cut waves instead: each wave is a short stack (or siblings) off main, merged before the next wave starts |
| Branch names | `<issue-key>/<part>`, so the issue tracker links them |
| Target level | `strict` for every file that can reach it |
| Team sign-off | In a shared repo, agree with the team before the infra PR, because it changes everyone's workflow |

Also get the tracking issue key. Its description should list the scope, the rule "CI enforces typecheck", "gradual", and "infra PR first".

## Phase 1: Infra PR

`references/infra.md` has the file-by-file checklist with templates. In summary:

1. **Gems and lockfile.** Add `sorbet` and `tapioca` to the dev/test group. `sorbet-static` has no `ruby`-platform gem, so lock concrete platforms, and pin `BUNDLE_FORCE_RUBY_PLATFORM=false` in `mise.toml [env]`, because sorah's shell exports `true` globally. Run `mise trust` afterwards.
2. **Configuration.**
   - Run `tapioca init`.
   - Point `outdir` at `third_party/` and add the second `--dir` to `sorbet/config`.
   - Enable `--parser=prism`, `--enable-experimental-rbs-comments` and `--enable-experimental-requires-ancestor`.
3. **Generate RBIs.**
   - Run `tapioca gem --all` and `tapioca annotations`. Exclude gems whose RBIs are huge and unused statically.
   - Run `tapioca dsl` for Rails. It boots the app against a real database, so bring the dev services up, and ask the user to authenticate when credentials are needed, rather than working around it.
4. **Green baseline at zero annotations.**
   - Files Sorbet cannot resolve get `# typed: ignore`: spec `Class.new` doubles, and files evaluated in another tool's DSL.
   - Do not add `--suppress-error-code`. If a code pattern forces one, such as `class Foo < Data.define`, fix the code in a small PR directly on top of infra.
5. **Discovery bump.**
   - In a throwaway branch, stamp sigils (see Phase 2) and run `spoom srb bump --from false --to true --dry` across everything.
   - Recurring gem gaps such as SemanticLogger `logger`, protobuf `Timestamp.from_time`, `TimeWithZone#floor` or `Time.current` go into `sorbet/rbi/shims/` in this PR, together with any custom tapioca compilers the survey called for.
   - Add `Must` (from the `sorbet` skill) and its spec here as well, so every slice can use it.
6. **Wiring.**
   - Task-runner tasks: `typecheck`, one task per project run in parallel, and `tapioca`, kept out of any `gen` task because it is slow and boots Rails.
   - Hook or lint steps: one per project, whose globs include the project's `third_party/` RBIs.
   - Exclude `third_party/sorbet/rbi/**` from the large-file check.
   - A CI `typecheck` job that installs only the bundles it needs; it takes about 30 s.
   - A CI check that new files start at `# typed: strict`, and, if `sorbet-runtime` is already in the bundle, a grep that bans `sig`/`T.` forms in `.rb` files.
7. **Docs.**
   - Write `docs/type-checking.md` with the sections Layout, Commands, Writing types, Nilable values, Union values, Strictness, Known gaps and References. Write it in the language the team's docs use.
   - Add a CLAUDE.md index entry and the rule that new files start at `# typed: strict`. Mirror the rule as a review rule if the project has a code-review bot.
8. **PR body.** Put the `spoom srb metrics` baseline in the PR body.

## Phase 2: Prep and sigils

- **Prep PRs.** Make small behaviour-preserving changes that let files resolve, such as `Data.define` assignment instead of inheritance. Each is its own PR on top of infra.
- **Sigils PR.**
  - `spoom srb bump` considers only files that already carry an explicit sigil. Without one it reports "No files to bump".
  - Stamp `# typed: false` as the first line of every `.rb` file in scope with `scripts/stamp_sigils.rb`, then run `srb tc`.
  - Check that annotation tools (annotaterb, rubocop autocorrect) keep the sigil on line 1.
  - This is one mechanical PR with no behaviour change.

## Phase 3: Slice plan

Order the slices bottom-up by call dependency, so each layer's callees are already typed. A typical Rails order:

1. `lib/` and `app/models/concerns/`
2. Infrastructure-like models such as key management, audit log and metrics
3. Value objects, `Data` types and parsers
4. Domain model clusters, from the least depended-on to the most
5. Service objects and engines
6. Serializers and shapes
7. Jobs, workers and mailers
8. Controller concerns
9. Controllers
10. `config/initializers`
11. Config root: `application.rb`, `routes.rb`, environments
12. In-repo engines, gems and sub-projects

Size each slice at 10 to 30 files, splitting a large directory by domain. Show the user a table with branch, glob and file count, and get approval before starting. Check with a script that every in-scope file lands in exactly one slice.

Each slice is one PR made of separate commits, so reviewers can skim the annotation-only commits and read the behavioural one:

1. `typing: <scope>`: raise to `true`. Annotations only.
2. `typing: <scope> to typed: strict`: a signature on every method, constant and instance variable. Annotations only, plus the allowed mechanical edits listed in the agent prompt.
3. `<scope>: <what changed>`: anything that changes runtime behaviour. This covers:
   - raising readers;
   - `else raise` arms and `Must` checks;
   - a result type split in two;
   - closing a real gap found while typing, such as a missing authorization gate. That fix comes with request specs.

   Leave this commit out when there is nothing to put in it. Bug fixes in sensitive domains (billing, auth) go in separate PRs rather than in the typing PR.

A file that cannot reach `strict` stays at `true` or `false`. Name the Sorbet limitation in the commit message and in docs Known gaps.

A suspected bug is never fixed silently inside an annotation commit. Report it, then fix it in commit 3 with a test, or file an issue.

## Phase 4: Run slices in parallel

The orchestrator (the main session) runs this phase:

1. Create one worktree per slice off the sigils branch, for example `git worktree add .git/w/<key>-<slice> -b <key>/<slice> <key>/sigils`. Run `mise trust` and initialize submodules in each.
2. In each worktree, write `tmp/slice.txt` with one path per line.
3. Launch every slice agent in a single message, in the background. The user expects real parallelism; launching one at a time was corrected. Fill the template in `references/slice-agent-prompt.md` for each slice.
4. When a running agent settles a new convention, such as a shim filename or how to handle a recurring DSL, send it to the other running agents with SendMessage and add it to the prompts of later runs.

Known traps:

- Agents drift back to the main checkout. Give absolute worktree paths, and require `cd <absolute path>` in every command.
- Every shell needs the mise environment, or `bundle` cannot resolve `sorbet-static`. Use `eval "$(mise env -s bash)";` or `mise x --`. The same applies inside the pre-commit hook.
- When specs share one test database, agents must not run rspec. The orchestrator runs the specs serially after integration. When each process gets its own database (`TEST_ENV_NUMBER`), agents may run their slice's specs.
- Hook steps that need generated or installed assets can fail in a fresh worktree. Tell agents how to install those assets. Never let them use `--no-verify`.
- Several slices create the same shim file. Expect add/add conflicts and union-merge them during integration.
- Never run `spoom bump --help`, the deprecated command. It ignores `--help` and bumps files.

## Phase 5: Integrate

1. Record every slice head, and the base each slice started from, in `tmp/<key>-heads-before.txt` before rewriting anything.
2. Chain the slices in plan order with `git rebase --onto <parent's new head> <slice's original base> <slice>`, so each slice replays only its own commits.
3. After each rebase, run `srb tc` for every project.
   - Fix an error in the lowest layer that owns the signature, then re-rebase upward.
   - The pre-commit hook runs `srb tc`, so fixes must go strictly bottom-up.
   - A dedicated "fix <layer> integration errors" agent per broken layer works well.
4. Check each rewrite with commit counts or `git range-diff`. A wrong upstream silently drops commits.
5. Run the specs layer by layer: the slice's spec directories plus request specs of the controllers that consume them. Run them serially if the test database is shared. Then run the full lint (`hk check --pr` or equivalent).
6. Submit following `/gh-stack`:
   - Run `gh stack init` with every branch.
   - Push each branch with `git push`.
   - Run `gh stack submit --auto` for draft PRs, under `timeout`.
   - If CI shares a scarce resource, such as a capped pool of test databases, push one or two branches at a time and wait for green.
7. Write each PR body with one paragraph per commit. Name every holdout file, every `untyped`, every widened parameter and every shim, each with its reason. End with "Every file this PR owns is at `# typed: strict` unless its commit says otherwise" and `Refs <key>`.
8. Post two comments on the tracking issue so a later session can resume:
   - the playbook: the per-slice loop, the slice table, and the traps above;
   - the follow-ups: bugs found, specs that could not run, holdouts, and areas that deserve a careful review.

## Phase 6: Review

1. **Audit the stack.**
   - Grep for `#: as`, `untyped`, `Kernel.`, `allocate`, `= self #:`, `send(:`, `public_send`, new parameters that carry narrowed copies, and comments that explain Sorbet.
   - Classify every site with Explore agents into a TSV with the columns site, category and proposed fix (`RESTRUCTURE`, `RAISING_READER`, `MUST`, `SHIM`, `KEEP`).
   - Write the plan before editing.
2. **Questions for the user.** Put them in `tmp/<key>-review.md`, one line per decision, each followed by a response slot and an HTML comment listing the options with the recommended one first.
3. **Review comments.**
   - A ruling on one site usually applies to every similar site in the stack, so apply it everywhere and say so.
   - Fix in the layer that owns the file, then rebase the layers above.
   - Answer questions in the thread with a diff or the `srb tc` output. Never resolve threads.
   - Before acting on a bot review, check it against the code.
   - Before defending a workaround, remove it and run `srb tc` again.

## Phase 7: Keep it current

- Rebasing the stack onto main can break any layer: files that main added or changed may not typecheck. Walk every layer.
  - Type a new file in the layer that owns its directory.
  - Add a new layer for a new domain when no existing layer fits.
- Regenerate RBIs after `Gemfile.lock` moves or a model changes. Nothing detects that drift automatically, so consider a scheduled job that regenerates them and opens a PR.
- After the stack merges:
  - keep the "new files are `typed: strict`" rule enforced;
  - collapse per-method `#: self as` lines in concerns into `# @requires_ancestor:` once the flag is enabled;
  - close the follow-up tickets.

## Effort

Timings from the original rollout (about 1750 methods and 300 files), for setting expectations. Scale them by method count.

| Step | Time |
|------|------|
| Infra PR | about 40 min |
| Sigils PR | minutes |
| 17 slices to `true` in parallel | about 45 min |
| Strict pass, about 22 agents with up to 10 in flight | about 2 h |
| Integration fixes | about 1 h per rebase onto main |
| Cast elimination | about 1 h 40 min |
| Pushing 20 PRs one at a time for green CI | about 3 h |

Review rounds then ran across several days.

## References

- **`references/infra.md`**: the infra PR checklist, with templates for `sorbet/config`, the tapioca config, mise tasks, hk steps, the CI job and the `docs/type-checking.md` skeleton
- **`references/slice-agent-prompt.md`**: the prompt template for a per-slice agent that takes files from `false` to `strict`
- **`scripts/stamp_sigils.rb`**: stamps `# typed: false` on files that have no sigil
