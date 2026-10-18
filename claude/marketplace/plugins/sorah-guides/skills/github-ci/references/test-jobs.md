# Test and lint jobs (`_test.yml`)

`_test.yml` has `on: workflow_call:`, top-level `permissions: contents: read`, and independent jobs so failures are reported separately and run in parallel. Typical jobs: a test matrix, `lint`, a type check, and freshness checks. Each job repeats `permissions: contents: read` and `timeout-minutes`.

## Table of contents

- Ruby gems
- Sorbet/Steep type checking
- Protobuf
- Rust crates
- Native extensions and caching
- Integration tests with services

## Ruby gems

```yaml
rspec:
  name: "rspec (Ruby ${{ matrix.ruby }})"
  runs-on: ubuntu-24.04
  timeout-minutes: 15
  permissions:
    contents: read
  # The gemspec supports >= 3.4, so both ends of that range are exercised.
  strategy:
    fail-fast: false
    matrix:
      ruby: ['3.4', '4.0']
  steps:
    - uses: actions/checkout@<sha> # vX
      with:
        persist-credentials: false
    - uses: ruby/setup-ruby@<sha> # vX
      with:
        ruby-version: ${{ matrix.ruby }}
        bundler-cache: true
    - run: bundle exec rspec --format documentation
```

- Matrix: the oldest Ruby the gemspec supports and the newest stable (currently `'3.4'` and `'4.0'`; `3.3` where still supported). Quote versions so `4.0` is not parsed as `4`.
- Monorepo: add `gem: [a, b]` to the matrix and `working-directory: ${{ matrix.gem }}` on the `bundle exec` step. An extra, narrower entry (`include:`) covers a gem needing a specific Ruby or env, with a comment saying why.
- `ruby/setup-ruby` with `bundler-cache: true` handles gem install and caching; there is no separate `actions/cache` for gems.
- Lint: `jdx/mise-action` then `hk check --all` (RuboCop, license headers, Sorbet, YARD coverage, buf, workflows).

## Sorbet/Steep type checking

Type checking runs as its own job, because it needs setup (RBS collection) that the other jobs do not:

```yaml
steep:
  steps:
    - ... checkout, setup-ruby (bundler-cache: true)
    - uses: actions/cache@<sha> # vX
      with:
        path: .gem_rbs_collection
        key: rbs-collection-${{ hashFiles('rbs_collection.lock.yaml') }}
        restore-keys: rbs-collection-
    - run: bundle exec rbs collection install --frozen   # CI checks against the reviewed signature versions
    - run: bundle exec rbs-inline --output=sig/generated lib
    - run: git diff --exit-code sig/generated            # fail if checked-in signatures are stale
    - run: bundle exec rbs -I sig/generated -I sig/manual validate
    - run: bundle exec steep check
```

The `lint` job then runs `hk check --all --skip-step steep` with a comment (`# steep runs in its own job, which prepares what it needs.`), so it is not run twice.

For Sorbet projects use `hk check` or `bundle exec srb tc` in the lint job; there is no extra setup.

## Protobuf

```yaml
proto:
  env:
    MISE_DISABLE_TOOLS: ruby
  steps:
    - ... checkout
    - uses: jdx/mise-action@<sha> # vX
    - run: buf lint
    - run: mise run protoc                           # or: buf generate
    - run: git diff --exit-code spec/fixtures        # committed output must not drift from the schema
```

- `buf breaking --against '.git#branch=origin/main'` on `pull_request` only, with `fetch-depth: 0` on checkout.
- The `buf`/`protoc` versions are pinned in `mise.toml`; a different version emits different descriptor bytes, so use mise rather than a separate setup action. `bufbuild/buf-action` with `setup_only: true` is fine where mise is not used.
- Skip `buf-lint` and `steep` in the generic lint job via `--skip-step` when they have their own jobs.

## Rust crates

```yaml
lint:
  runs-on: ubuntu-latest
  steps:
    - ... checkout
    - uses: jdx/mise-action@<sha> # vX
    - uses: dtolnay/rust-toolchain@<sha> # master
      with:
        toolchain: stable
        components: clippy, rustfmt
    - run: hk check --all --slow       # cargo fmt, clippy and workflow linting, same as local

test:
  strategy:
    fail-fast: false
    matrix:
      include:
        - { os: ubuntu-latest }
        - { os: ubuntu-24.04-arm }
  runs-on: ${{ matrix.os }}
  steps:
    - ... checkout
    - uses: dtolnay/rust-toolchain@<sha> # master
      with:
        toolchain: stable
    - run: cargo test
```

- Test on both x86_64 and aarch64 Linux using native runners. Use the `*-musl` targets (with `musl-tools` and `taiki-e/setup-cross-toolchain-action`) when the release artifacts are musl, so tests exercise what ships; test native gnu instead when a dependency makes musl builds heavy (e.g. `aws-lc-sys`), with a comment saying so.
- Add `aarch64-apple-darwin` on `macos-latest` only when macOS is a supported target (and `MACOSX_DEPLOYMENT_TARGET: '11.0'` with a comment).
- When the same target/dependency setup repeats across several jobs, factor it into `.github/actions/setup` (inputs `target`, `rust-toolchain`) with `shell: bash` on every `run:` step.
- A `build: true` boolean input on `_test.yml` runs an additional `cargo build` matrix for CI (and not for releases, which build for real afterwards). Share the matrix with a YAML anchor (`matrix: &matrix` / `matrix: *matrix`).
- CI may use `Swatinem/rust-cache`; release and package-building jobs do not (see SKILL.md).
- `cargo install` / tool installs in CI go through `taiki-e/install-action` (e.g. `tool: bpf-linker,cargo-deb`) rather than compiling from source.

## Native extensions and caching

- Compiled dependencies (Rust/C++ extension gems): `mozilla-actions/sccache-action` with `RUSTC_WRAPPER: sccache` and `SCCACHE_GHA_ENABLED: "true"`; name the C/C++ compiler explicitly (`CC=gcc`, `CXX=g++` / `clang`) via `$GITHUB_ENV` so the `cc` crate routes through the wrapper.
- Large downloads (VM images, rbs collections, rubies built in a container) use `actions/cache` keyed on a version or lockfile hash, with a comment on what the cache holds.
- A job installing the gem under test the way users do (`gem build` + `gem install` + smoke script) catches missing vendored files in the gemspec.
- Long jobs raise `timeout-minutes` deliberately (90–180) and say why.

## Integration tests with services

- Prefer `services:` containers. When the service needs command-line arguments (unsupported by `services:`), start it with `docker run -d --net=host --rm <image>` in a step, and leave a FIXME explaining why (acmesmith's Pebble).
- Tests needing root, BPF, or KVM run as separate reusable workflows (`_integration.yml`, `_fuzz.yml`) called from `ci.yml` and `release.yml` in parallel with `_test.yml`, so the privileged job's surface is isolated. Enable KVM with the udev rule step; cache the VM image.
- Fuzzing runs as a short pass in CI per target (matrix over fuzz targets), nightly toolchain, and is also part of the scheduled run.
