# Infra Commit Checklist

What the first commit of a Steep rollout contains, with templates taken from `problem` and `protobufable`. If the repo has no mise, hk or GitHub Actions, put the same commands into whatever task runner and CI the project already uses.

## Contents

1. Dependencies
2. Steepfile
3. RBS collection
4. Rakefile
5. hk
6. CI
7. Gemspec files
8. DESIGN.md

## 1. Dependencies

```ruby
# <gem>.gemspec
spec.add_development_dependency "rbs", "~> 4.0"
spec.add_development_dependency "rbs-inline", "~> 0.14"
spec.add_development_dependency "steep", "~> 2.0"
```

A project that keeps development dependencies in the Gemfile adds them there with `require: false` instead. Check the current major versions before pinning.

## 2. Steepfile

```ruby
# frozen_string_literal: true

target :lib do
  signature "sig/generated", "sig/manual", "sig-stub"
  check "lib"

  # protoc output, typed by hand in sig/manual.
  ignore "lib/**/*_pb.rb"
end
```

- Drop `sig-stub` until the first stub exists, and the `ignore` until there is generated code.
- During the rollout, not-yet-typed paths go under `ignore` with a comment saying they are pending. The list shrinks to generated and Sorbet-only code by the end.
- Stdlib signatures that no gem manifest pulls in are listed as `library "securerandom"`.
- Keep the default diagnostics. Coverage is checked in review, not by raising severity.

## 3. RBS collection

```yaml
# rbs_collection.yaml
# Signatures for third-party gems, fetched from ruby/gem_rbs_collection.
# Run `bundle exec rbs collection install` after changing this file.
sources:
  - type: git
    name: ruby/gem_rbs_collection
    remote: https://github.com/ruby/gem_rbs_collection.git
    revision: main
    repo_dir: gems

path: .gem_rbs_collection

gems:
  # Development-only tooling; nothing in lib/ calls it.
  - name: rbs
    ignore: true
  - name: steep
    ignore: true
  - name: rspec-core
    ignore: true
  - name: rspec-expectations
    ignore: true
  - name: rspec-mocks
    ignore: true
  - name: rspec-support
    ignore: true
  - name: rubocop
    ignore: true
```

```gitignore
# Installed by `rbs collection install`; the lock file is what is checked in.
/.gem_rbs_collection/
```

When a dependency needs a local source (see the `steep` skill), add it first in `sources`, with a comment saying why the upstream entry is not used:

```yaml
sources:
  - type: local
    path: rbs
```

```yaml
# rbs/<gem>/<version>/manifest.yaml (only when it depends on stdlib signatures)
dependencies:
  - name: time
```

## 4. Rakefile

```ruby
desc "Regenerate inline RBS signatures under sig/generated"
task :rbs do
  sh "rbs-inline --output=sig/generated lib"
  sh "rbs -I sig/generated -I sig/manual validate"
end

desc "Type check lib against the RBS signatures"
task steep: :rbs do
  sh "steep check"
end

task default: [:spec, :steep]
```

## 5. hk

```pkl
// sig/generated is rbs-inline output, checked as generated rather than linted.
exclude = List("sig/generated/**")

// steep type checks the whole project at once, so no file list is passed.
["steep"] {
  glob = List("lib/**/*.rb", "sig/**/*.rbs", "sig-stub/**/*.rbs", "Steepfile")
  check = "bundle exec steep check"
}
```

## 6. CI

Use the `steep` job in the `github-ci` skill's `references/test-jobs.md`. It caches `.gem_rbs_collection` on the lock file, installs with `--frozen`, regenerates `sig/generated`, fails on `git diff --exit-code sig/generated`, validates, and runs `steep check`. The lint job runs `hk check --all --skip-step steep`. Add `-I sig-stub` to the validate step when that directory exists. Run the job on one Ruby version, the newest the gemspec supports.

## 7. Gemspec files

Ship `sig/`, never `sig-stub/` or the tooling configuration.

```ruby
spec.files = Dir["lib/**/*.rb", "sig/**/*.rbs", "README.md", "LICENSE.txt", "CHANGELOG.md"]
```

For a `git ls-files` list, add `Steepfile rbs_collection sig-stub/` to the rejected prefixes. Check the result with `gem build` and a listing of the package.

## 8. DESIGN.md

Add a Types section, kept short:

- Signatures are rbs-inline annotations generated into `sig/generated`, committed and verified current in CI, because an annotation can change without anyone regenerating.
- `sig/manual` holds what inline annotations cannot express, as a list: self-type interfaces for concerns, `class_attribute` accessors, `Data` classes with a custom `initialize`, hand-typed generated code.
- `sig-stub/` and any local collection source, with the reason each third-party gap exists.
- Which DSL blocks are `steep:ignore`d and why.
