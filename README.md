# sorah config

Dotfiles and machine setup. `setup.sh` is the entry point; the declarative
parts live in `mise.toml` and `mise/tools.toml`, applied by
[`mise bootstrap`](https://mise.jdx.dev/bootstrap.html).

| Path | What |
| --- | --- |
| `setup.sh` | The whole run, idempotent: Homebrew and the Brewfile, the aur-sorah pacman repository, mise and every bootstrap phase, and the imperative leftovers (rustup, claude plugins). |
| `mise.toml` | `[dotfiles]` for the dotfiles, `[bootstrap.packages]` for macOS app casks and the Arch pacman and AUR packages, `[bootstrap.macos]` for UI preferences, `[bootstrap.linux.systemd.units]` for the systemd user units. |
| `mise/tools.toml` | The global tool set and the `[settings]` that govern it. Deployed to `~/.config/mise/conf.d/sorah-tools.toml`, so it applies in every directory rather than only in this repo. |
| `Brewfile` | What Homebrew still owns: sudo-requiring casks, formulae, Mac App Store apps. |

## New machine

```bash
mkdir -p ~/git && git clone git@github.com:sorah/config.git ~/git/config
cd ~/git/config && ./setup.sh
```

You have to:

- Accept the Xcode command line tools at the first `git` prompt (macOS).
- Clone to `~/git/config` — `misc/dot.gitconfig` is included by absolute path.
- Sign in to the App Store first, or the `mas` entries fail (macOS).
- Enter an admin password for the first cask group (macOS).
- Log out and back in, for input sources (AquaSKK/ABC), the fn key action and
  modifier-key remapping on already-connected keyboards (macOS).

The platform comes from `/etc/pacman.conf` and `uname`; pass `arch`, `linux` or
`mac` as `$1` to override. `[bootstrap.packages]` holds every platform's
packages and each entry is applied only where its manager exists, so the casks
are inert on Arch and the `pacman:`/`aur:` entries are inert on macOS.
`[bootstrap.macos]` is macOS-scoped the same way.

## Migrating an existing machine

`./setup.sh` converges an existing machine without reinstalling anything, but
applies everything without asking. To transfer ownership step by step instead,
first look:

```bash
mise self-update
cd ~/git/config && mise trust
mise bootstrap packages status
mise bootstrap macos defaults status
mise bootstrap dotfiles status
mise bootstrap linux systemd-units status
```

Then apply:

```bash
mise bootstrap --only macos-defaults --yes
mise bootstrap --only dotfiles --yes
mise trust ~/.config/mise/conf.d/sorah-tools.toml
mise bootstrap --only tools --yes
mise bootstrap packages apply --manager aur --yes   # Arch
mise bootstrap --only linux-systemd-units --yes     # Linux
```

- Every package should already read `installed`: mise reads the Homebrew prefix
  directly, and a Homebrew-owned cask satisfies its entry without mise taking
  ownership, so no app bundle is replaced and Privacy & Security grants survive.
- A dotfile reading `differs (exists but is not a symlink)` blocks the whole
  dotfiles phase, not just its own entry. Move it aside by hand, or let
  `./setup.sh` do it. Not `--force-dotfiles`: for a directory target it deletes
  the directory.
- `--only macos-defaults` and not `mise bootstrap macos defaults apply`, which
  skips the `post-defaults` hook that restarts Dock, Finder and SystemUIServer.
- `min_version` in `mise.toml` stops an older mise with self-update
  instructions, so the `self-update` above is only to get it over with early.
- `gopls` is `pacman:gopls` on Arch and a `go:` entry in `mise/tools.toml` on
  macOS. `~/.gopath/bin` precedes both `/usr/bin` and the mise shims in
  `~/.zshrc`, so `setup.sh` deletes `~/.gopath/bin/gopls`; a `go install` copy
  left there would keep winning.
- An old `bazelisk-bin` from yay conflicts with `pacman:bazelisk` without
  providing it, which fails the whole pacman transaction. `setup.sh` removes
  it first; by hand, `sudo pacman -Rdd bazelisk-bin`.
- On Arch, `packages status` should show everything `installed` too: both
  backends read pacman's database, and `pacman:` resolves groups and virtual
  provides, so `base-devel`, `netcat`, `bind-tools` and `ebtables` count as
  installed through `base-devel`'s members, `openbsd-netcat`, `bind` and
  `iptables`.

Finally, strip `~/.config/mise/config.toml` down to two settings, deleting the
`[tools]` and `[tool_alias]` tables:

```bash
mise unuse --global --no-prune $(mise ls --current 2>/dev/null | awk '$3 ~ /config\.toml$/ {print $1}')
```

- `config.toml` overrides `conf.d`, so while an entry is duplicated there it,
  not this repo, decides that tool's version. `mise/tools.toml` declares all of
  them, so both tables can go entirely.
- Some of them are declared here under a different name, so check before
  assuming a tool disappeared: `aws-cli` and `pinact` are the `aqua:` entries,
  `gh` is `github-cli`, `ubi:sqldef/sqldef` is `sqlite3def`, the two `ubi:`
  smithy entries are the `github:` `[tool_alias]` definitions, and any other
  `ubi:owner/repo` is `github:owner/repo`.
- Keep `[settings] paranoid` and `[settings] disable_tools`; delete the other
  settings. `experimental`, `lockfile`,
  `idiomatic_version_file_enable_tools` and `npm.package_manager` live in
  `mise/tools.toml` now, and a `conf.d` fragment serves them once trusted.
  `paranoid` is the one that cannot move -- mise wants trust before parsing a
  symlink into this repo, and an unparsed file cannot be what turns paranoid
  on -- and `disable_tools` is per machine.
- `--no-prune` keeps the installations. Unrelated to `mise prune`, which deletes
  unused tool versions and never edits configuration.

## After a `git pull`

```bash
cd ~/git/config && git pull && ./setup.sh
```

Or apply just the declarative half:

```bash
mise trust && mise trust ~/.config/mise/conf.d/sorah-tools.toml
mise bootstrap --dry-run
mise bootstrap --yes
```

- Both `mise trust` calls are needed after any pull that touches `mise.toml` or
  `mise/tools.toml`: paranoid mode binds trust to file contents, and an
  untrusted config is skipped rather than applied.
- A full bootstrap runs the `post-defaults` hook every time, restarting Dock,
  Finder, SystemUIServer and ControlCenter. `mise bootstrap --only
  packages,tools --yes` avoids that.
- A bare `mise bootstrap` cannot install the `aur:` entries on a machine that
  has no AUR helper yet: mise's AUR backend shells out to yay, yay is a mise
  tool, and the packages phase runs before the tools phase. It reports them as
  `skipped (neither yay nor paru found)` rather than failing, and
  `mise bootstrap packages apply --manager aur --yes` picks them up afterwards.
  `setup.sh` does exactly that.
- Removals need hands. A tool dropped from `mise/tools.toml` stays installed
  (`mise unuse`), a cask dropped from `[bootstrap.packages]` stays installed
  (`mise bootstrap packages prune --dry-run`), a dotfile dropped from
  `[dotfiles]` stays deployed (`mise bootstrap dotfiles unapply`), and a
  deleted macOS preference keeps its value — mise never deletes a default.
  `prune` covers Homebrew only; `pacman` and `aur` answer `does not support
  pruning`, so a dropped Arch package needs `pacman -Rs` by hand.

## Dotfiles

`[dotfiles]` in `mise.toml` deploys them. Most are symlinks into the repo, so
editing the live file edits the repo.

`~/.config/karabiner/karabiner.json` and
`~/.config/linearmouse/linearmouse.json` are `mode = "copy"`: both apps rewrite
their config in place, which replaces a symlink with a regular file. The repo
is the source of truth, and an apply overwrites the target — plain file or
symlink — without `--force`.

Platform-specific entries (`~/.zshrc_global_env`, the Linux `.desktop` file)
use a logical key with the target in `variants`, since a dotfile entry has no
`os` key of its own. An entry whose variants do not match is not deployed.

`~/.tmux.reattacher` is generated by `setup.sh`, and `ghq.root` and
`include.path` stay `git config --global` so a machine can override them.

By hand:

- Run `mise bootstrap dotfiles add --changed` to capture app-side edits to the
  copy-mode files into the repo. An apply discards whatever was not captured.
- Delete the `<name>.pre-mise.<timestamp>` backups `setup.sh` leaves behind
  when it moves a conflicting target aside.

## systemd user units

`[bootstrap.linux.systemd.units]` in `mise.toml` generates them from structured
keys rather than from a unit file in the repo, so every directive is a TOML key
and string values are Tera templates.

mise installs each as `dev.mise.<name>.service`, not `<name>.service`.
`setup.sh` removes the bare-named copies it used to install, disabling and
stopping them first.

`homeproxy` is declared `wanted_by = []` and `start = false`: installed, but
with no `[Install]` section and not running. To run it on a machine:

```bash
systemctl --user add-wants default.target dev.mise.homeproxy.service
systemctl --user start dev.mise.homeproxy
```

`add-wants` rather than `enable`, which needs an `[Install]` section. Both
undone by the next apply, which converges the unit back to disabled and
stopped.

## Notes

- `mise use -g` writes to `~/.config/mise/config.toml`, which overrides the
  repo's fragment. Fold ad-hoc installs back into `mise/tools.toml`.
- `mise bootstrap status` summarises every declarative part; every apply takes
  `--dry-run`.
- `logitech-g-hub` stays in the Brewfile because its cask installer runs sudo,
  which mise's own cask implementation rejects.
- `pacman:` and `aur:` entries can only be `"latest"`. Arch repositories carry
  one version of each package, and an AUR helper builds the current PKGBUILD.
- `pacman -S --needed` never refreshes the sync databases, so `setup.sh` runs
  `pacman -Sy` before the packages phase. A full `-Syu` stays a manual
  decision.
- yay comes from `github:Jguer/yay`, not the `mise-yay` asdf plugin it
  replaced. Delete the old one with `mise uninstall
  asdf:mise-plugins/mise-yay` once the new one works; while both are installed
  the shim order decides which mise calls. paru is not usable here at all --
  its release binary links `libalpm.so.15` and Arch is on `.so.16`.
- The deprecated `ubi:` backend is not used; `github:` replaces it. Installs
  made through it linger until removed with `mise uninstall --all ubi
  ubi:kagehq/port-kill ubi:sorah/mairu ubi:ayinke-llc/sdump`. A registry tool
  such as `k9s` may also have been installed through ubi; `mise doctor` names
  those, and `mise uninstall --all k9s && mise install k9s` moves it back.
- The `github:` backend queries the GitHub API on install, whose anonymous rate
  limit a full bootstrap exceeds. `setup.sh` exports `GITHUB_TOKEN` from `gh
  auth token` when `gh` is logged in.

## License

Copyright (c) 2020 Sorah Fukumori

Available under the MIT License unless otherwise noted.
