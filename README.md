# sorah config

Dotfiles and machine setup. `setup.sh` is the entry point; the declarative
parts live in `mise.toml` and `mise/tools.toml`, applied by
[`mise bootstrap`](https://mise.jdx.dev/bootstrap.html).

| Path | What |
| --- | --- |
| `setup.sh` | The whole run, idempotent: Homebrew and the Brewfile, mise and every bootstrap phase, dotfile symlinks, the Arch package lists, and the imperative leftovers (rustup, gopls, claude plugins, systemd units). |
| `mise.toml` | `[bootstrap.packages]` for macOS app casks, `[bootstrap.macos]` for UI preferences, `[dotfiles]` to deploy the tool set. |
| `mise/tools.toml` | The global tool set. Deployed to `~/.config/mise/conf.d/sorah-tools.toml`, so it applies in every directory rather than only in this repo. |
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
`mac` as `$1` to override. On Arch the packages come from pacman and yay inside
`setup.sh`, and the `[bootstrap.packages]` and `[bootstrap.macos]` sections are
macOS-scoped and inert.

## Migrating an existing machine

`./setup.sh` converges an existing machine without reinstalling anything, but
applies everything without asking. To transfer ownership step by step instead,
first look:

```bash
mise self-update
cd ~/git/config && mise trust
mise bootstrap packages status
mise bootstrap macos defaults status
```

Then apply:

```bash
mise bootstrap --only macos-defaults --yes
mise bootstrap --only dotfiles --yes
mise trust ~/.config/mise/conf.d/sorah-tools.toml
mise bootstrap --only tools --yes
```

- Every package should already read `installed`: mise reads the Homebrew prefix
  directly, and a Homebrew-owned cask satisfies its entry without mise taking
  ownership, so no app bundle is replaced and Privacy & Security grants survive.
- `--only macos-defaults` and not `mise bootstrap macos defaults apply`, which
  skips the `post-defaults` hook that restarts Dock, Finder and SystemUIServer.
- `min_version` in `mise.toml` stops an older mise with self-update
  instructions, so the `self-update` above is only to get it over with early.

Finally, delete the `[tools]` and `[tool_alias]` tables from
`~/.config/mise/config.toml`, by hand or:

```bash
mise unuse --global --no-prune go node python terraform
```

- `config.toml` overrides `conf.d`, so while an entry is duplicated there it,
  not this repo, decides that tool's version. `mise/tools.toml` declares all of
  them, so both tables can go entirely.
- Keep `[settings] paranoid`. `setup.sh` asserts it, and the fragment cannot:
  mise wants trust before parsing a symlink into this repo, and an unparsed
  file cannot be what turns paranoid on.
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
- Removals need hands. A tool dropped from `mise/tools.toml` stays installed
  (`mise unuse`), a cask dropped from `[bootstrap.packages]` stays installed
  (`mise bootstrap packages prune --dry-run`), and a deleted macOS preference
  keeps its value — mise never deletes a default.

## Notes

- `mise use -g` writes to `~/.config/mise/config.toml`, which overrides the
  repo's fragment. Fold ad-hoc installs back into `mise/tools.toml`.
- `mise bootstrap status` summarises every declarative part; every apply takes
  `--dry-run`.
- `logitech-g-hub` stays in the Brewfile because its cask installer runs sudo,
  which mise's own cask implementation rejects.

## License

Copyright (c) 2020 Sorah Fukumori

Available under the MIT License unless otherwise noted.
