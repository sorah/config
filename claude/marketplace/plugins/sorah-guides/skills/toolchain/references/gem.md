# Ruby Gem Template

Taken from sorah/protobufable. Replace the versions with current releases, and drop the protobuf and steep parts when the gem has neither.

## mise.toml

```toml
[tools]
ruby = "4.0.6"
"aqua:bufbuild/buf" = "1.58.0"
# buf.gen.yaml uses protoc_builtin, which shells out to protoc rather than bundling it.
# Pinned, because a different version emits different descriptor bytes and the freshness
# check in CI compares them.
"aqua:protocolbuffers/protobuf/protoc" = "34.1"
"aqua:jdx/hk" = "2.0.1"
"aqua:apple/pkl" = "0.31.1"
"aqua:rhysd/actionlint" = "1.7.12"
"aqua:zizmorcore/zizmor" = "1.30.1"

[settings]
disable_backends = ["asdf"]

[settings.ruby]
compile = false

[tasks.pre-commit]
run = "hk run pre-commit"

[tasks.protoc]
description = "Regenerate the Ruby message classes from the .proto sources"
run = [
  "buf generate proto --template buf.gen.yaml",
]
```

## hk.pkl

```pkl
amends "package://github.com/jdx/hk/releases/download/v2.0.1/hk@2.0.1#/Config.pkl"
import "package://github.com/jdx/hk/releases/download/v2.0.1/hk@2.0.1#/Builtins.pkl"

// sig/generated is rbs-inline output and lib/**/*_pb.rb is protoc output; both are checked
// as generated rather than linted.
exclude = List("sig/generated/**", "lib/**/*_pb.rb")

local linters = new Mapping<String, Step> {
  ["rubocop"] {
    glob = List("**/*.rb", "**/*.rake", "Rakefile", "*.gemspec")
    check = "bundle exec rubocop --force-exclusion {{files}}"
    fix = "bundle exec rubocop --force-exclusion --autocorrect {{files}}"
    batch = true
  }
  // steep type checks the whole project at once, so no file list is passed.
  ["steep"] {
    glob = List("lib/**/*.rb", "sig/**/*.rbs", "Steepfile")
    check = "bundle exec steep check"
  }
  ["buf-lint"] {
    glob = List("proto/**/*.proto", "buf.yaml")
    check = "buf lint"
  }
  ["actionlint"] = Builtins.actionlint
  ["byte-order-marker"] = Builtins.byte_order_marker
  ["check-added-large-files"] = Builtins.check_added_large_files
  ["check-merge-conflict"] = Builtins.check_merge_conflict
  ["check-symlinks"] = Builtins.check_symlinks
  ["detect-private-key"] = Builtins.detect_private_key
  ["mise"] = Builtins.mise
  ["mixed-line-ending"] = Builtins.mixed_line_ending
  ["newlines"] = Builtins.newlines
  ["pkl"] = Builtins.pkl
  ["pkl-format"] = Builtins.pkl_format
  ["trailing-whitespace"] = Builtins.trailing_whitespace
  ["zizmor"] = Builtins.zizmor
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

## bin/setup

```sh
#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

bundle install
if command -v hk >/dev/null 2>&1; then hk install; fi
```

## CI lint job

```yaml
lint:
  runs-on: ubuntu-latest
  env:
    # Ruby comes from setup-ruby, which also caches the bundle.
    MISE_DISABLE_TOOLS: ruby
  steps:
    - uses: actions/checkout@<sha> # vX
      with:
        persist-credentials: false
    - uses: ruby/setup-ruby@<sha> # vX
      with:
        bundler-cache: true
    - uses: jdx/mise-action@<sha> # vX
    # steep runs in its own job, which prepares the rbs collection it needs.
    - name: hk check
      run: hk check --all --skip-step steep
```
