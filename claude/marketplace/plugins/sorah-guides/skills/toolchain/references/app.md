# Application Fragments

Taken from ruby-no-kai/sponsor-app, a Rails app with protobuf code generation, Sorbet and a `ui/` frontend with its own lockfile. Combine these with the gem template's baseline builtins and hooks.

## mise.toml

```toml
[env]
# sorbet-static ships only precompiled platform gems, which a `ruby` lockfile
# platform cannot resolve.
BUNDLE_FORCE_RUBY_PLATFORM = "false"

[tasks.typecheck]
description = "Sorbet type check"
run = "bundle exec srb tc"

# Regenerating every gem RBI takes minutes and `tapioca dsl` boots Rails, so
# this runs on demand after a Gemfile.lock or model change.
[tasks.tapioca]
description = "Regenerate Sorbet RBI files under third_party/"
run = [
  "bundle exec tapioca gem --all",
  "bundle exec tapioca annotations",
  "bundle exec tapioca dsl",
]

# hk's gen step and CI's gen job both run this, so registering a generator here
# covers both.
[tasks.gen]
description = "Run every generator whose output is checked into git"
depends = ["gen:proto", "gen:rbi"]

[tasks."gen:proto"]
description = "Generate Ruby and RBS into gen/proto/ruby, and TypeScript into ui/src/gen"
depends = ["ui:install"]
sources = ["proto/**/*.proto", "buf.gen.yaml", "buf.yaml", "buf.lock", "ui/pnpm-lock.yaml"]
outputs = { auto = true }
run = '''
set -eu

# A .proto that fails to compile must leave gen/ untouched.
buf build

find gen/proto/ruby ui/src/gen \( -name '*_pb.rb' -o -name '*_pb.rbs' -o -name '*_pb.ts' \) -delete
buf generate
'''

# mise skips this while node_modules/.pnpm/lock.yaml is newer than the sources. A no-op install
# leaves that file as it is, hence the touch.
[tasks."ui:install"]
description = "Install ui/ dependencies from its lockfile"
dir = "{{config_root}}/ui"
run = "pnpm install --frozen-lockfile && touch node_modules/.pnpm/lock.yaml"
sources = ["package.json", "pnpm-lock.yaml", "pnpm-workspace.yaml"]
outputs = ["node_modules/.pnpm/lock.yaml"]

[tasks."ui:typecheck"]
description = "Typecheck ui/"
depends = ["ui:install"]
dir = "{{config_root}}/ui"
run = "pnpm run typecheck"
```

## hk.pkl

```pkl
// Paths `mise run gen` writes into, which formatters must not rewrite.
local generated = List(
  "gen/**",
  "ui/src/gen/**",
)

local linters = new Mapping<String, Step> {
  ["rubocop"] {
    workspace_indicator = ".rubocop.yml"
    check = "cd {{workspace}} && bundle exec rubocop --force-exclusion {{ workspace_files }}"
    fix = "cd {{workspace}} && bundle exec rubocop --force-exclusion --autocorrect {{ workspace_files }}"
    batch = true
  }
  // srb typechecks the whole project at once, so no file list is passed. It
  // reads the message RBIs the gen step rewrites.
  ["sorbet"] {
    glob = List("**/*.rb", "**/*.rbi", "sorbet/config", "Gemfile.lock")
    check = "bundle exec srb tc"
    depends = "gen"
  }
  // mise skips each generator whose sources are unchanged, so this needs no
  // glob. `hk check` skips it, and CI's gen job verifies the output instead.
  ["gen"] {
    fix = "mise run gen"
    stage = generated
  }
  ["newlines"] = (Builtins.newlines) {
    exclude = generated
  }
  // ui/ has a pnpm-lock.yaml of its own, so it is a workspace of its own.
  ["oxfmt"] {
    workspace_indicator = "pnpm-lock.yaml"
    glob = "**/*.{ts,tsx,js,jsx,css}"
    exclude = generated
    check = "cd {{workspace}} && npx oxfmt --check {{ workspace_files }}"
    check_list_files = "cd {{workspace}} && npx oxfmt --list-different {{ workspace_files }}"
    fix = "cd {{workspace}} && npx oxfmt --write {{ workspace_files }}"
    batch = true
  }
  // ...baseline builtins as in the gem template
}
```

## CI gen job

```yaml
gen:
  steps:
    - ... checkout, setup-ruby, mise-action
    - run: mise run --force gen
    - name: Check generated files are current
      run: |
        if [ -n "$(git status --porcelain)" ]; then
          git status --porcelain
          echo "Generated files are stale. Run 'mise run gen' and commit the result." >&2
          exit 1
        fi
```
