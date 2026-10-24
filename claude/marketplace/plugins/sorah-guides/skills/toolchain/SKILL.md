---
name: toolchain
description: This skill should be used when setting up or changing a project's developer toolchain with mise and hk, such as creating or editing `mise.toml`, `mise.lock` or `hk.pkl`, adding a tool, a task, a linter, a formatter, a code generator or a pre-commit hook, or scaffolding a new gem, app or repository. Use it whenever the user mentions "mise", "hk", "pkl", "pre-commit", "git hooks", "lint step", "hk check", "mise run", "mise task", "pin a tool version", or "gen task", even if they only say "add rubocop to the hooks" or "add a generator". Provides the mise.toml layout (aqua-pinned tools, settings, env, tasks with sources/outputs, the gen umbrella), the hk.pkl layout (a linters mapping shared by pre-commit, fix and check hooks, builtins, whole-project steps, workspaces, generated paths), hook installation, and how CI runs both. Project-specific conventions always take priority.
version: 0.1.0
---

# Toolchain: mise and hk

How sorah's projects pin tools and run tasks with [mise](https://mise.jdx.dev), and run linters and formatters with [hk](https://hk.jdx.dev). The same `hk check` runs as the pre-commit hook, by hand, and in CI, so a change that passes locally passes in CI. Canonical examples: sorah/protobufable for a gem, ruby-no-kai/sponsor-app for a Rails app with generated code. `references/` has copyable templates. Follow an existing project's own layout over this guide.

## mise.toml

- The file is `mise.toml`, not `.mise.toml`. `ruby/setup-ruby` does not read the dotted name.
- Comments sit above the entry they explain and say why it exists or why it is pinned, in full sentences.

### Tools

```toml
[tools]
ruby = "4.0.6"
"aqua:jdx/hk" = "2.0.1"
"aqua:apple/pkl" = "0.31.1"
"aqua:rhysd/actionlint" = "1.7.12"
"aqua:zizmorcore/zizmor" = "1.30.1"
```

- Pin every tool to an exact version, including tools that `~/git/config/mise/tools.toml` installs globally at `latest`. The project pin is what CI and other machines reproduce. Look up the current release before writing a version.
- Spell out the backend: `aqua:<owner>/<repo>` first, `github:<owner>/<repo>` when aqua has no entry. `ruby`, `node` and `rust` use the core plugins. Short registry names (`hk`, `pnpm`) resolve to a backend that can change underneath the project.
- A tool whose version changes generated output gets a comment naming what it must match, such as protoc: `# The protobuf release that google-protobuf in Gemfile.lock is built from.`
- `latest` is right only when pinning means nothing, with the reason in a comment.
- `rust = { version = "1.97.1", components = "rustfmt,clippy" }` for a Rust project.

### Settings and env

```toml
[settings]
disable_backends = ["asdf"]

[settings.ruby]
compile = false
```

- `disable_backends = ["asdf"]` keeps a tool from resolving to an unaudited asdf plugin. `compile = false` installs prebuilt Rubies.
- `lockfile = true` comes from the global configuration. Commit `mise.lock`, and never commit `mise.local.lock`.
- `[env]` holds only what the project needs to build, each with a comment. Sorbet projects set `BUNDLE_FORCE_RUBY_PLATFORM = "false"`, because sorah's shell exports `true` and `sorbet-static` ships only platform gems.
- Run `mise trust` after creating or editing `mise.toml`; mise refuses to run tasks from an untrusted file.

### Tasks

- Every project has `[tasks.pre-commit] run = "hk run pre-commit"`, and `[tasks.setup] run = "bin/setup"` when it has one.
- Name tasks with colon namespaces: `gen:proto`, `ui:install`, `lint:proto`. Give each a `description`.
- A subproject's tasks set `dir = "{{config_root}}/ui"`.
- A generator declares `sources` and `outputs = { auto = true }`, so mise skips it while its inputs are unchanged.
- An install task touches a marker so mise can skip a no-op install: `run = "pnpm install --frozen-lockfile && touch node_modules/.pnpm/lock.yaml"` with that file as `outputs`.
- When the repo checks in generated files, one umbrella task lists every generator:
  ```toml
  # hk's gen step and CI's gen job both run this, so registering a generator here
  # covers both.
  [tasks.gen]
  description = "Run every generator whose output is checked into git"
  depends = ["gen:proto", "gen:rbi"]
  ```
- Slow tasks that boot the app, such as `tapioca`, stay out of `gen` and run on demand, with a comment saying when.

## hk.pkl

```pkl
amends "package://github.com/jdx/hk/releases/download/v2.0.1/hk@2.0.1#/Config.pkl"
import "package://github.com/jdx/hk/releases/download/v2.0.1/hk@2.0.1#/Builtins.pkl"

local linters = new Mapping<String, Step> {
  // project steps first, then builtins in alphabetical order
}

hooks {
  ["pre-commit"] {
    fix = true
    stash = "git"
    steps {
      ...linters
      ["no-commit-to-branch"] = Builtins.no_commit_to_branch
    }
  }
  ["fix"] {
    fix = true
    steps = linters
  }
  ["check"] {
    steps = linters
  }
}
```

- The `amends` and `import` URLs carry the same version as the `aqua:jdx/hk` pin. Bump all three together.
- One `linters` mapping feeds all three hooks, so the pre-commit hook, `hk fix` and `hk check` never drift apart. Only pre-commit adds `no-commit-to-branch`.
- The baseline builtins for every repo: `actionlint`, `byte-order-marker`, `check-added-large-files`, `check-merge-conflict`, `check-symlinks`, `detect-private-key`, `mise`, `mixed-line-ending`, `newlines`, `pkl`, `pkl-format`, `trailing-whitespace`, `zizmor`. Add `buf_format` and `buf_lint` for protobuf. Builtin names changed in hk 2 (`byte_order_marker` replaced the check/fix pair), so check the Builtins of the pinned version.
- Every custom step and every override has a `//` comment saying why it is shaped that way.

### Steps

- A per-file tool takes `{{files}}` and `batch = true`:
  ```pkl
  ["rubocop"] {
    glob = List("**/*.rb", "**/*.rake", "Rakefile", "*.gemspec")
    check = "bundle exec rubocop --force-exclusion {{files}}"
    fix = "bundle exec rubocop --force-exclusion --autocorrect {{files}}"
    batch = true
  }
  ```
  `--force-exclusion` makes RuboCop honour its own `Exclude` for files hk passes explicitly.
- A whole-project checker (steep, srb, tsc, cargo clippy) has a glob that decides when it runs, and no file list, with the comment `// steep type checks the whole project at once, so no file list is passed.`
- In a repo with several projects, use `workspace_indicator` (`.rubocop.yml`, `pnpm-lock.yaml`, `Cargo.toml`) with `cd {{workspace}} && ... {{ workspace_files }}`.
- Tweak a builtin by amending it: `["newlines"] = (Builtins.newlines) { exclude = generated + List(...) }`.
- The generator step runs the umbrella task and stages its output. Steps that read generated files `depends = "gen"`:
  ```pkl
  // mise skips each generator whose sources are unchanged, so this needs no
  // glob. `hk check` skips it, and CI's gen job verifies the output instead.
  ["gen"] {
    fix = "mise run gen"
    stage = generated
  }
  ```

### Generated paths

List generated paths once and keep linters away from them: a top-level `exclude = List("sig/generated/**", "lib/**/*_pb.rb")` when nothing should touch them, or `local generated = List(...)` reused in each step's `exclude` and the gen step's `stage`. Add `vendor/**` when CI installs gems there.

## Hooks

- Install with `hk install`; never configure git hooks any other way. `bin/setup` runs it when hk is present: `if command -v hk >/dev/null 2>&1; then hk install; fi`.
- The README's development section lists `mise install` then `hk install`.
- Never bypass the hook with `--no-verify`. Fix what it reports, or ask.

## CI

The lint job installs mise with `jdx/mise-action` and runs `hk check --all`. Steps that need setup the lint job lacks run in their own job and are skipped with `--skip-step <name>`, each with a comment. A repo with a `gen` task has a gen job that runs `mise run --force gen` and fails when `git status --porcelain` is not empty. The `github-ci` skill has the job templates.

## References

- **`references/gem.md`**: a complete `mise.toml` and `hk.pkl` for a Ruby gem
- **`references/app.md`**: `mise.toml` and `hk.pkl` fragments for an app with generated code, workspaces and a frontend
- <https://mise.jdx.dev/tasks/> and <https://hk.jdx.dev/configuration.html>
