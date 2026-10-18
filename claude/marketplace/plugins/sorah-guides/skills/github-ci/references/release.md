# Release workflows

## Table of contents

- Shape of every release
- Tags
- Draft GitHub release
- Ruby gems (trusted publishing)
- Rust crates and binaries
- Attestations
- Container images
- release-plz (workspaces)
- Ordering

## Shape of every release

`release.yml` is triggered by a tag push, never by a branch or a manual dispatch, so the released bits are exactly the tagged commit. It runs `_test.yml` first and gates everything on it (`needs: [test]`), then builds, then publishes to the registry last.

```yaml
name: release

on:
  push:
    tags:
      - 'v*'

permissions:
  contents: read

jobs:
  test:
    permissions:
      contents: read
    uses: ./.github/workflows/_test.yml # zizmor: ignore[self-repository]

  release:
    needs: [test]
    runs-on: ubuntu-24.04
    timeout-minutes: 20
    environment:
      name: rubygems
      url: https://rubygems.org/gems/<name>
    permissions:
      contents: write
      id-token: write
    steps: ...
```

The `environment:` is required for trusted publishing: the registry's trusted-publisher setting names the repo, workflow file, and environment, so a compromised unrelated workflow cannot publish. Give it a `url:` so the deployment links to the published artifact.

## Tags

| Repo kind | Tag | Trigger pattern |
| --- | --- | --- |
| Single gem / crate | `vX.Y.Z` | `'v*'` (Ruby) or `'v[0-9]+.*'` (Rust) |
| Monorepo of gems | `<gem>/vX.Y.Z` (`Bundler::GemHelper.tag_prefix`), gem name = subdirectory | `'<gem>/v*'` per gem |
| Deliverable bundling several crates, or `.deb`s | CalVer `rel/YYYY.MM.DD.NN` | `'rel/*'` |
| Container image released independently of gems | `lambda/YYYY.MM.DD.NN` | `'lambda/*'`, with a job that validates the format with a regex and fails with `::error::` |

For a monorepo, derive the gem from the tag in a first step and expose `name`, `version`, and `url` as step outputs; reuse them for `working-directory:` and `environment.url`:

```yaml
- name: Identify gem from tag
  id: gem
  run: |
    gem_name="${GITHUB_REF_NAME%/v*}"
    version="${GITHUB_REF_NAME##*/v}"
    {
      echo "name=${gem_name}"
      echo "version=${version}"
      echo "url=https://rubygems.org/gems/${gem_name}/versions/${version}"
    } >> "$GITHUB_OUTPUT"
```

When one workflow handles several tag families, route jobs with `if: startsWith(github.ref_name, 'lambda/')` / `if: "!startsWith(...)"`.

For Rust, fail the release early when the tag disagrees with the manifest:

```bash
VERSION="${GITHUB_REF_NAME#v}"
grep -q "^version = \"${VERSION}\"" Cargo.toml || { echo "::error::Tag version ${VERSION} does not match Cargo.toml"; exit 1; }
```

## Draft GitHub release

Releases are always created as **drafts**, with notes generated and `--verify-tag` so a missing tag fails instead of being created implicitly. A human reads the notes and publishes the draft. A comment says so (`# Left as a draft so the notes can be read before they are announced.`).

```yaml
- name: Create GitHub release
  run: gh release create "${GITHUB_REF_NAME}" --verify-tag --generate-notes --draft
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

Variants:

- Make creation idempotent when later jobs upload assets and the workflow may be re-run: `gh release view "$TAG" --json id >/dev/null 2>&1 || gh release create ...`. Upload with `gh release upload ... --clobber`.
- Projects with a keep-a-changelog `CHANGELOG.md` use the section for the tagged version as the body (plus GitHub's "Full Changelog" compare line), via `actions/github-script` (see himari or glazed `release.yml`). Create the release in a single `createRelease` call with `tag_name`, because updating a draft without `tag_name` detaches it from its tag. Fail when the section is missing.
- Extra release-time information (checksums, Terraform `source_sha512`) is appended to the notes with `gh release edit --notes "${existing}${block}"` in a final job (see sts-cat).

## Ruby gems (trusted publishing)

No API key is stored. `rubygems/release-gem` runs `rake release` through OIDC; the tag already exists, so it only builds and pushes.

```yaml
steps:
  - uses: actions/checkout@<sha> # vX
    with:
      persist-credentials: false
  - uses: ruby/setup-ruby@<sha> # vX
    with:
      ruby-version: '4.0'
      # Not cached: a restored cache would be a way to smuggle code into the
      # gem this job publishes.
      bundler-cache: false
  - run: bundle install
  - name: Create GitHub release
    run: gh release create "${GITHUB_REF_NAME}" --verify-tag --generate-notes --draft
    env:
      GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
  - name: Publish to RubyGems
    uses: rubygems/release-gem@<sha> # vX
    # with: working-directory: ${{ steps.gem.outputs.name }}   (monorepo)
```

Precompiled native gems (protovalidate-rb): `native.yml` builds per platform and Ruby minor in a `workflow_call`/`workflow_dispatch` workflow and uploads `gem-*` artifacts; `release.yml` runs it alongside `_test.yml`, downloads them into `pkg/` (`pattern: gem-*`, `merge-multiple: true`), and `release-gem` pushes `pkg/*` next to the source gem. Build Linux gems in a digest-pinned `manylinux_2_34` container and check glibc/GLIBCXX symbol ceilings, so gems load on older distributions.

## Rust crates and binaries

Order of jobs: `test` → `create-release` (draft, validates version) → `build-binaries` / `build-lambda` / `build-deb` (upload to the draft) → `publish-crate` last.

`publish-crate` is last because publishing a crate cannot be undone (`cargo yank` leaves the version taken), whereas a failed binary upload can simply be re-run:

```yaml
publish-crate:
  needs: [build-binaries]
  runs-on: ubuntu-latest
  environment:
    name: crates-io
    url: https://crates.io/crates/<name>
  permissions:
    contents: read
    id-token: write
  steps:
    - uses: actions/checkout@<sha> # vX
      with:
        persist-credentials: false
    - uses: dtolnay/rust-toolchain@<sha> # master
      with:
        toolchain: stable
    - uses: rust-lang/crates-io-auth-action@<sha> # vX
      id: auth
    - run: cargo publish --no-verify
      env:
        CARGO_REGISTRY_TOKEN: ${{ steps.auth.outputs.token }}
```

Binaries: matrix of `x86_64-unknown-linux-musl` on `ubuntu-latest`, `aarch64-unknown-linux-musl` on `ubuntu-24.04-arm`, and `aarch64-apple-darwin` on `macos-latest` when macOS is supported. Steps: `musl-tools` via apt, `dtolnay/rust-toolchain` with `targets`, `taiki-e/setup-cross-toolchain-action`, then `taiki-e/upload-rust-binary-action` (`bin`, `target`, `tar: unix`, `token: ${{ secrets.GITHUB_TOKEN }}`) which uploads to the release by tag. Set `MACOSX_DEPLOYMENT_TARGET: '11.0'` for macOS builds. `.deb` via `cargo-deb`, built clean (no rust-cache) on each architecture's native runner, uploaded as `deb-<arch>` artifacts by a reusable `_deb.yml`, shared by CI (nightly artifacts) and release.

## Attestations

Everything downloadable gets a provenance attestation, in the job that produced (or downloaded) the file:

- Files: `actions/attest` with `subject-path: <file>` (or `actions/attest-build-provenance` with a glob such as `dist/*.deb`). Needs `id-token: write` and `attestations: write`.
- Images: `actions/attest-build-provenance` with `subject-name: <image repo>`, `subject-digest: ${{ steps.push.outputs.digest }}`, `push-to-registry: true`.
- When a reusable build workflow is shared with CI, attest in the release workflow after downloading the artifacts, so the reusable one stays a plain build-and-upload.

## Container images

- Registry: `ghcr.io/<owner>/<image>` using `GITHUB_TOKEN` with `packages: write` (login via `docker/login-action`, `username: ${{ github.actor }}`), or ECR Public through an OIDC role (`aws-actions/configure-aws-credentials` with `role-to-assume`, `role-skip-session-tagging: true`) for AWS-hosted deployments (himari).
- Steps: `docker/setup-buildx-action` → `login-action` → `docker/metadata-action` (tags `type=sha`, `type=ref,event=branch`, `type=semver,pattern=v{{version}}` and `v{{major}}.{{minor}}`) or an explicit tag list → `docker/build-push-action`.
- Write the commit to a `REVISION` file before building (`echo "$GITHUB_SHA" > REVISION`) and set `org.opencontainers.image.{source,revision,licenses}` labels.
- Layer cache: `cache-from: type=gha`, `cache-to: type=gha,mode=max` on branch builds; omit on release builds.
- Push only after tests and only for `push` events (`needs: [test]`, `if: github.event_name == 'push'`); pull requests build nothing that publishes.
- Wrap it as `_docker.yml` / `_lambda-image.yml` (`workflow_call` with `tags` and `cache` inputs; lowercase the owner with `${OWNER,,}`) so `ci.yml` (branch tags, `latest`) and `release.yml` (version tags) share it.

## release-plz (workspaces)

For a Rust workspace where releases are driven by a release PR (trustless): a `workflow_dispatch` workflow runs `release-plz/action` with `command: release-pr`, and `ci.yml` calls `_release.yml` (`command: release`) after tests on pushes to main. Both:

- obtain a GitHub token through `sorah/sts-cat/.github/actions/exchange-token` (pinned by SHA), with a trust policy in `.github/sts-cat/<identity>.sts.toml` bound to the repo's `crates-io` environment, so a PR created by the workflow triggers CI (a `GITHUB_TOKEN` PR does not) without a PAT;
- get the crates.io token from `rust-lang/crates-io-auth-action`;
- run in the `crates-io` environment.

Binary tarballs for the released crates are then built and attached to a combined `rel/YYYY.MM.DD.NN` draft release created by `actions/github-script`.

## Ordering

Put the irreversible step last, and the step that a human reviews (draft release) before it: test → build artifacts → attach/attest → publish to registry. A failed release job is then re-runnable by re-running the workflow or re-pushing the tag, without a half-published version.
