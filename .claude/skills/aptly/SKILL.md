---
name: aptly
description: Maintain sorah's aptly-managed APT repositories (nkmideb and sorah-ruby, published to the sorah-pkg S3 bucket) with the bin/sorah-aptly-* scripts. Use whenever the user wants to add or upload .deb/.dsc packages to a distro, publish or re-publish (publish update), add support for a new Debian/Ubuntu release (e.g. forky, resolute), remove or yank a broken package version, find which distros carry a package, or anything mentioning aptly, nkmideb, sorah-ruby apt repo, rbpkg, ~/.aptly, or "publish to the apt repo", even if they don't say "aptly".
---

# aptly maintenance

The local aptly DB lives in `~/.aptly` (config `~/.aptly.conf`). Two publish targets share it:

| Target | Repos | Endpoint (S3 `sorah-pkg`) | GPG key | Extra publish flags |
|---|---|---|---|---|
| `nkmideb` | `nkmideb-<distro>` | `s3:nkmideb:` (prefix `nkmideb/`) | `3D38A16556C57C162F0D6F5AA3599225C3FF3305` | `-label=Nkmideb -origin=Nkmideb` |
| `sorah-ruby` (alias `ruby`) | `sorah-ruby-<distro>`, some `-proposed` | `s3:sorah-ruby:` (prefix `ruby/`) | `805E57E2327EE86EB8180E0669CEB9D53F0F56A8` | none |

Each repo publishes as distribution `<distro>`, component `main`, architectures `amd64,arm64,source`. Older publishes predate those defaults: several lack arm64 or source, and nkmideb has no label/origin before bookworm. `sorah-aptly-new-distro` warns about such differences when rerun on an existing distro; leave them alone unless the user wants to republish. These values live in `bin/lib/sorah_aptly.rb`; update that file, not the individual scripts, if a target changes.

## Scripts

All are in `bin/` (on PATH). Every mutating script takes `-n`/`--dry-run`, which prints the aptly commands without running them. Run a dry-run first for anything that removes packages or touches many distros, and show the user what will happen.

| Script | Purpose |
|---|---|
| `sorah-aptly-find TARGET\|all QUERY [-d distros]` | List matching packages per repo (read-only) |
| `sorah-aptly-add TARGET FILE... [-d distros] [-p]` | `repo add` files; distro taken from the `~<distro>` version suffix in each filename, or `-d` to add every file to the listed distros |
| `sorah-aptly-remove TARGET QUERY [-d distros] [-p]` | `repo remove` matching packages from all (or listed) repos |
| `sorah-aptly-publish-update TARGET [DISTRO...]` | `publish update` with the right key; all published distros if none given |
| `sorah-aptly-new-distro TARGET DISTRO... [--proposed]` | `repo create` + initial `publish repo` with the target's flags |

`-p`/`--publish` on add/remove runs `publish update` for exactly the distros that changed. Without it the script prints the follow-up `sorah-aptly-publish-update` command.

The scripts refuse unknown distros, which catches loop typos (`focla`, `bullssye`) that used to silently fail mid-loop.

## Credentials

Only S3 operations (`publish repo`, `publish update`, `publish drop`, and anything with `-p`) need AWS credentials. The scripts don't fetch them; prefix the command with the mairu wrapper:

```
mairu exec --server nkmi '341857463381/AdministratorAccess' sorah-aptly-publish-update nkmideb noble
```

The user's interactive shell has this as the `ma` alias (`ma sorah-aptly-publish-update ...`); aliases don't expand in non-interactive shells, so spell it out when running it yourself. Signing uses gpg-agent, so a publish may block on a pinentry prompt or fail with "Inappropriate ioctl for device"; if so, ask the user to unlock the signing key rather than skipping signatures.

Local operations (`find`, `add`/`remove` without `-p`, `repo create`) need no credentials.

## Package queries

`find` and `remove` take an aptly package query (https://www.aptly.info/doc/feature/query/):

- `etherip-xdp`: by package name
- `etherip-xdp, $Version (= 0.1.0-r2026062200)`: exact version
- `$Version (% *nkmi2*)`: glob match; `(~ regex)` for regex
- `$Source (ruby3.4)`: everything built from a source package, including -dbgsym and `_source`
- `Name (libruby), $Architecture (arm64)`; `|` for OR, `!` for NOT

Epochs are part of `$Version` (`1:3.4+0nkmi2~noble`), and versions carry a `~<distro>` suffix, so prefer `%` globs over `=` when matching across distros.

## Common workflows

Releasing a build from `.changes` files: prefer `sorah-deb-release {ruby|nkmideb} *.changes`, which also creates the GitHub release and then adds and publishes. Use `sorah-aptly-add` for bare `.deb`/`.dsc` files or when the GitHub release already exists.

Adding a build:

```
sorah-aptly-add -n nkmideb out/*1.14.1*.deb     # check grouping
mairu exec ... sorah-aptly-add -p nkmideb out/*1.14.1*.deb
```

A distro-independent package (filename without `~distro`) needs `-d jammy,noble,resolute,trixie`. A `.dsc` pulls its `.orig.tar.*`/`.debian.tar.*` from the same directory, so keep them together.

Yanking a bad version: `sorah-aptly-find` to confirm the scope, `sorah-aptly-remove -n`, then `-p` for real. Removing only drops references; the pool files stay until `aptly db cleanup`. Use `aptly db cleanup -dry-run` and then `aptly db cleanup` rather than deleting files under `~/.aptly/pool` by hand.

Supporting a new release (e.g. Debian forky): `sorah-aptly-new-distro nkmideb forky` (and `sorah-ruby forky` if ruby builds exist), under credentials. Publishing an empty repo is fine.

Changing publish parameters of an existing distro (architectures, label/origin) cannot be done with `publish update`. Drop and re-publish:

```
aptly publish drop -skip-cleanup <distro> s3:<target>:
sorah-aptly-new-distro <target> <distro>   # repo exists, so it only publishes
```

`-skip-cleanup` keeps the pool objects in S3 so clients don't hit 404s between the drop and the new publish. Confirm with the user before any `publish drop`: it makes the distro briefly unavailable to apt clients.

## Raw aptly gotchas

- `aptly publish update` and `publish drop` take `<distribution> <endpoint>` (`noble s3:nkmideb:`), not a repo name. `publish repo` takes the repo name.
- `aptly repo show -with-packages REPO`: the flag must come before the repo name.
- `aptly publish list -raw` lines look like `s3:nkmideb:. noble`.
- Without `-gpg-key`, `publish update` signs with the default gpg key, which is wrong for both targets. The scripts always pass it.
- The DB is a single leveldb; concurrent aptly processes fail with a lock error, so don't run aptly commands in parallel.
