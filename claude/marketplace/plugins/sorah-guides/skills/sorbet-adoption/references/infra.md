# Infra PR Checklist

What the first PR of a Sorbet rollout contains, with templates. `<project>` is a directory with its own Gemfile; the templates use `web` for a Rails app and `client` for a gem in the same repo. Repeat the per-project steps for each one. If the repo has no mise, hk or GitHub Actions, put the same commands into whatever task runner and CI the project already uses.

## Contents

1. Gems and platforms
2. Sorbet and tapioca configuration
3. Generating RBIs
4. Baseline
5. Shims and Must
6. Task runner, hooks, CI
7. Documentation

## 1. Gems and platforms

```ruby
# Gemfile (or the gemspec's development dependencies for a gem)
group :development, :test do
  gem "sorbet", require: false
  gem "tapioca", require: false
end
```

`sorbet-static` is published only as precompiled gems for x86_64-linux, aarch64-linux, universal-darwin and java, with no `ruby` platform. Bundler then cannot resolve it whenever `ruby` is among the lockfile platforms or the platform is forced.

```sh
bundle lock --add-platform x86_64-linux aarch64-linux arm64-darwin
bundle lock --remove-platform ruby
```

```toml
# mise.toml: sorah's ~/.zshrc exports BUNDLE_FORCE_RUBY_PLATFORM=true
[env]
# sorbet-static is published only as precompiled platform gems; a `ruby`
# resolution platform makes it unresolvable.
BUNDLE_FORCE_RUBY_PLATFORM = "false"
```

Run `mise trust` after editing `mise.toml`. If you skip it, the mise shims silently fail. Every shell that runs `bundle`, including the pre-commit hook and subagent shells, needs the mise environment. Without it, `bundle install` and `bundle exec` backtrack for minutes and then fail.

## 2. Sorbet and tapioca configuration

Run `bundle exec tapioca init` in each project, then edit the generated files:

```text
# <project>/sorbet/config
--dir
.
--dir
../third_party/sorbet/rbi/<project>
--ignore=tmp/
--ignore=log/
--ignore=storage/
--ignore=vendor/
--parser=prism
--enable-experimental-rbs-comments
--enable-experimental-requires-ancestor
```

```yaml
# <project>/sorbet/tapioca/config.yml
gem:
  outdir: "../third_party/sorbet/rbi/<project>/gems"
  dsl_dir: "../third_party/sorbet/rbi/<project>/dsl"
dsl:
  outdir: "../third_party/sorbet/rbi/<project>/dsl"
annotations:
  # The upstream activesupport annotations declare String#as_json and
  # Array#to_xml with no arguments, contradicting the gem RBIs (Sorbet 4010).
  typed_overrides:
    activesupport: "false"
```

For a gem with no Rails, drop the `dsl` keys and the `typed_overrides` unless they are needed.

```ruby
# <project>/sorbet/tapioca/require.rb
# typed: true
# frozen_string_literal: true

# Entrypoints the app reaches for but `Bundler.require` does not load, either
# because the Gemfile marks them `require: false` or because the gem lazy-loads
# the constant.
require "connection_pool"
```

```text
# .gitattributes
/third_party/sorbet/rbi/** linguist-generated=true
```

`tapioca annotations` has no output-directory option, so its RBIs stay in `<project>/sorbet/rbi/annotations/`. Hand-written shims go in `<project>/sorbet/rbi/shims/`.

## 3. Generating RBIs

```sh
bundle exec tapioca gem --all
bundle exec tapioca annotations
bundle exec tapioca dsl          # Rails only
```

`tapioca dsl` boots Rails, and its ActiveRecord compilers connect to the real database. When that database needs credentials, such as cloud IAM or a VPN, ask the user to authenticate. Skipping a credentials initializer only moves the failure elsewhere.

If a gem's entrypoint does not load some constants, for example generated protobuf files required lazily from routes, add the requires to `require.rb`, or rely on the DSL pass to pick them up.

## 4. Baseline

`bundle exec srb tc` must be green with zero annotations, before any file is raised.

- Give `# typed: ignore` to specs that build `Class.new` doubles defining `initialize` or `self.name`. Do the same for files evaluated in a foreign DSL that cannot resolve, and for initializers that guard on a gem the project does not depend on.
- Do not add `--suppress-error-code`. A pattern that forces one, such as `class Foo < Data.define(...)`, gets a small fix-up PR directly on top of infra.
- Record `bundle exec spoom srb metrics` (files per strictness level, methods with and without signatures) in the PR body.

## 5. Shims and Must

Before opening the PR, find the gem gaps every slice would otherwise work around on its own:

```sh
# throwaway branch only
ruby <skill>/scripts/stamp_sigils.rb $(git ls-files 'app/**/*.rb' 'lib/**/*.rb' 'config/**/*.rb')
bundle exec spoom srb bump --from false --to true --dry
bundle exec srb tc 2>&1 | grep 'https://srb.help/' | sed -E 's/^[^:]+:[0-9]+: //' | sort | uniq -c | sort -rn | head -40
```

Recurring "method does not exist" errors on gem constants become shims in `sorbet/rbi/shims/`. See the `sorbet` skill's `references/known-gaps.md` for the usual ones. Add `Must` and its spec in this PR too.

## 6. Task runner, hooks, CI

```toml
# mise.toml
# One srb per project, so mise runs them in parallel.
[tasks.typecheck]
description = "Sorbet type check every project"
depends = ["typecheck-web", "typecheck-client"]

[tasks.typecheck-web]
dir = "{{ config_root }}/web"
run = "bundle exec srb tc"

# Not part of `gen`: regenerating every gem RBI takes minutes and `tapioca dsl`
# boots Rails, so this runs on demand after a Gemfile.lock or model change.
[tasks.tapioca]
description = "Regenerate Sorbet RBI files under third_party/"
depends = ["tapioca-web", "tapioca-client"]

[tasks.tapioca-web]
dir = "{{ config_root }}/web"
run = ["bundle exec tapioca gem --all", "bundle exec tapioca dsl"]
```

```pkl
// hk.pkl: srb typechecks a whole project at once, so no file list is passed.
// One step per project: its RBIs live under third_party/, outside any
// workspace a workspace_indicator could resolve.
["sorbet-web"] {
  glob = List(
    "web/**/*.rb",
    "web/**/*.rbi",
    "web/**/*.rake",
    "web/Rakefile",
    "web/sorbet/**",
    "third_party/sorbet/rbi/web/**",
  )
  check = "cd web && bundle exec srb tc"
}
// Several generated gem RBIs are over a megabyte.
["check-added-large-files"] = (Builtins.check_added_large_files) {
  exclude = List("third_party/sorbet/rbi/**")
}
```

```yaml
# .github/workflows/<test>.yml: only the bundles srb needs, no database or node
typecheck:
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@<pinned sha> # vX
      with:
        persist-credentials: false
    - uses: jdx/mise-action@<pinned sha> # vX
    - uses: ruby/setup-ruby@<pinned sha> # vX
      with:
        working-directory: web
        bundler-cache: true
    - run: mise run typecheck
```

Pin actions by SHA, the way the repository's other workflows do.

## 7. Documentation

Create `docs/type-checking.md` with these sections, and keep it the single place a reader looks:

- **Layout**: a table of `sorbet/config`, `sorbet/tapioca/{config.yml,require.rb}`, `sorbet/rbi/annotations/`, `sorbet/rbi/shims/` and `third_party/sorbet/rbi/<project>/{gems,dsl}`, marking which are generated.
- **Commands**: `mise run typecheck`, `bundle exec srb tc`, `hk check`, `mise run tapioca`, `tapioca gem --all`, `tapioca dsl` and `tapioca annotations`. Say when to regenerate.
- **Writing types**: inline `#:` and `#|` syntax, nilable values (the `Must` ladder), union values (`Must.be_a`, `#: absurd`).
- **Strictness**: what each sigil level reports, the per-file adoption rule, and `spoom srb bump`.
- **Known gaps**: each Sorbet limitation the project hit, with its workaround. This grows with every slice.
- **References**: sorbet.org/docs/rbs-support, sorbet.org/docs/gradual, Shopify/spoom, plus the CI job and hk step locations.

Add the doc to the CLAUDE.md documentation index. Also add the rule "new Ruby files under app/, lib/ and config/ start at `# typed: strict`; specs stay unsigiled" where reviewers and agents will see it: CLAUDE.md, and a code-review bot rule if the project has one.
