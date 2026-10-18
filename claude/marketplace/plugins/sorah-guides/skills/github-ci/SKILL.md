---
name: github-ci
description: This skill should be used when writing, editing, or reviewing GitHub Actions workflows (`.github/workflows/*.yml`, composite actions in `.github/actions/`), or when setting up CI, a release pipeline, a Docker image build, or gem/crate publishing for a project. Use it whenever the user mentions "GitHub Actions", "CI", "workflow", "release workflow", "trusted publishing", "pin actions", "zizmor", "actionlint", or asks to "add tests to CI", "publish on tag", or "build a container image in CI", even if they never say "workflow". Provides the standard workflow layout (ci / `_test` / release), least-privilege and SHA-pinning rules, release and publishing patterns, and per-language test jobs. Project-specific conventions always take priority.
version: 0.1.0
---

# GitHub Actions Conventions

Common design across sorah's projects (acmesmith, himari, glazed, protobufable, protovalidate-rb, mairu, sts-cat, trustless, etherip-xdp, and others). The newest repos (glazed, protobufable, protovalidate-rb, etherip-xdp) define the standard; older ones (mairu, sts-cat, bluetooth-getty) predate the hardening below. Match the standard in anything written or touched, but do not mass-rewrite unrelated workflows in an older repo.

Project-specific conventions (CLAUDE.md, an existing workflow's local idioms) take priority.

## Layout

Workflows are thin entry points that call reusable workflows, so CI, PRs, and releases run exactly the same checks.

```
.github/
  workflows/
    ci.yml          # push to the default branch + pull_request → calls _test.yml
    release.yml     # tag push → _test.yml, then build/publish
    _test.yml       # workflow_call: lint, tests, type check, freshness checks
    _<name>.yml     # other reusable pieces (_docker, _deb, _lambda-image, _integration, _fuzz)
  actions/setup/    # composite action, only for setup repeated by 3+ jobs (e.g. Rust target + apt deps)
```

- A leading underscore marks a `workflow_call`-only file. Anything shared by `ci.yml` and `release.yml` lives there. Every release re-runs `_test.yml` as `needs`, because a tag can be pushed on a commit that never passed CI.
- `ci.yml`: `on: push: branches: [main]` plus `pull_request:`. One file covers both. Split into `main.yml` and `pr.yml` only when push and PR do different things (image push, deploy). A scratch branch (`ci`, `test`) may be added to the push list to try CI changes without a PR.
- `_test.yml` states in a one-line comment which local command it mirrors, and that no secrets are required (e.g. `# The checks rake, hk check and mise run protoc run locally. No secrets required.`).
- Add a `schedule:` cron (an odd minute, e.g. `'36 7 2,12,22 * *'`) to `ci.yml` for projects with external moving parts (ACME servers, kernels, base images), so drift surfaces without a push.
- Non-trivial shell goes in `.github/scripts/*.sh`, not inline `run:` blocks over ~15 lines.

## Security baseline

`zizmor` and `actionlint` check these (see Linting below), and each exists for a reason. Workflows run with write access to the repo and publishing credentials, so the supply chain around them is the attack surface.

**Permissions: least privilege, declared twice.** Set `permissions: {}` (or `contents: read`) at workflow top level, then grant per job. A caller job that uses a reusable workflow must itself carry the permissions the callee needs.

```yaml
permissions: {}

jobs:
  test:
    permissions:
      contents: read
    uses: ./.github/workflows/_test.yml # zizmor: ignore[self-repository]
```

Escalations are always job-local and named for their purpose: `id-token: write` (OIDC / trusted publishing / attest), `packages: write` (ghcr.io), `attestations: write`, `contents: write` (create release). Never at workflow level.

**Pin every third-party action to a full commit SHA**, with the version in a trailing comment. Tags can be moved; SHAs cannot.

```yaml
- uses: actions/checkout@d23441a48e516b6c34aea4fa41551a30e30af803 # v6.1.0
  with:
    persist-credentials: false
```

- Resolve a SHA with `gh api repos/<owner>/<repo>/commits/<tag> --jq .sha` (handles annotated tags). Prefer copying the pin from the most recently updated sibling repo, then check for a newer release.
- Actions that publish no tags (`dtolnay/rust-toolchain`) are pinned to a master commit with `# master` (add the date when helpful). A SHA pin no longer selects the toolchain, so pass `with: toolchain: stable` explicitly.
- Never `@main`, `@master`, `@v4`, or `@stable` for a third-party action (`cargo-bins/cargo-binstall@main` and `actions/checkout@v4` in older repos are the pattern to retire).
- Local reusable workflows carry `# zizmor: ignore[self-repository]` on the `uses:` line.

**`persist-credentials: false`** on every `actions/checkout` unless the job later pushes with that token (then pass an explicit `token:` instead).

**No expression interpolation in `run:` or `script:`.** Pass values through `env:` and read shell variables, so a crafted tag or branch name cannot become code.

```yaml
- run: gh release create "${GITHUB_REF_NAME}" --verify-tag --generate-notes --draft
  env:
    GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

Prefer built-in variables (`$GITHUB_REF_NAME`, `$GITHUB_SHA`, `$GITHUB_REPOSITORY`) over `${{ github.* }}` inside scripts. For `actions/github-script`, pass inputs via `env:` and read `process.env`.

**Secrets**: prefer OIDC over stored secrets (trusted publishing for RubyGems and crates.io, `aws-actions/configure-aws-credentials` with a role, `sts-cat` token exchange instead of a PAT). Use `secrets: inherit` only when the callee genuinely needs secrets, and say why.

**Release jobs do not restore caches.** A restored cache is a way to smuggle code into what the job signs and publishes. Use `bundler-cache: false` + `bundle install` there, and no `rust-cache`/`sccache` (see `references/release.md`).

## Job hygiene

- `timeout-minutes` on every job (5 for glue, 15 for tests, 20–30 for builds; far more only for native extension builds). The default 360 hides hangs and burns minutes.
- `strategy.fail-fast: false` on every matrix, so one failing combination does not hide the others.
- Runners: `ubuntu-24.04` (or `ubuntu-latest`); `ubuntu-24.04-arm` for native arm64 instead of emulation; `macos-latest`/`macos-15` only when macOS matters; `ubuntu-slim` for trivial glue jobs (create a release, compute a matrix).
- `concurrency` on `ci.yml`: `group: ci-${{ github.head_ref || github.ref }}` with `cancel-in-progress: true`. Never on release workflows.
- Give matrix jobs a readable `name:` (`rspec (Ruby ${{ matrix.ruby }})`), and a comment saying why the matrix has those members (`# The gemspec supports >= 3.4, so both ends of that range are exercised.`).
- A job that checks generated output regenerates it, then fails on drift: `git diff --exit-code [path]`. Applies to inline RBS (`rbs-inline`), protobuf codegen (`buf generate` / `mise run protoc`), and lockfiles.
- Shell steps use `set -euxo pipefail` when multi-line; failures annotate with `echo "::error::<message>"`. For apt: `sudo apt-get install -y X || (sudo apt-get update && sudo apt-get install -y X)`, which skips the slow update when the image already has the package.
- Comments follow the coding guide: state why a step exists or a version is pinned, never what the step does. Keep them to a line or two.

## Linting the workflows

Workflows are linted locally and in CI by the same command as the rest of the code: `hk check --all`, with the hk builtins `actionlint` and `zizmor` enabled in `hk.pkl` and `"aqua:zizmorcore/zizmor"` pinned in `mise.toml`. The Ruby repos (glazed, protobufable) have both; the Rust repos (plana, sts-cat) have only `actionlint`, so add `zizmor` when touching their workflows. `_test.yml`'s `lint` job runs `jdx/mise-action` then `hk check --all` (`--slow` for Rust, to include clippy). Where Ruby comes from `ruby/setup-ruby` rather than mise, set `MISE_DISABLE_TOOLS: ruby` on that job. Run `hk check --all` after editing any workflow and fix findings rather than adding `zizmor: ignore`, except the self-repository case above and cases with a stated reason (e.g. `adhoc-packages` for installing the gem under test).

## Where to look next

- Test/lint job templates for Ruby gems, Rust crates, protobuf/Sorbet/Steep projects, and matrix conventions: `references/test-jobs.md`
- Tag-triggered releases, trusted publishing, draft releases, binaries, attestations, container images, release-plz: `references/release.md`

Read the relevant reference before writing a `_test.yml` or `release.yml` from scratch, then compare against the most similar sibling repo under `~/git/github.com/sorah/` (Ruby gem: protobufable or glazed; Rust CLI: sts-cat or jsondepnet; Rust workspace with release-plz: trustless; native extension gem: protovalidate-rb; image-only: himari).
