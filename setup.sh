#!/usr/bin/env zsh
#
# All-in-one machine setup. Idempotent: safe to re-run.
#
#   ./setup.sh [mac|arch|linux]
#
# The declarative half lives in mise.toml (macOS app casks, the Arch package
# lists, macOS preferences, the dotfiles, the systemd user units) and
# mise/tools.toml (the global tool set), applied from here through
# `mise bootstrap`. The Brewfile holds what Homebrew owns. See README.md.
#
# Deliberately no `set -e`, so one failing step does not strand the rest.

repo=${0:A:h}
cd "$repo" || exit 1

arch=${1:-}
if [[ -z $arch && -e /etc/pacman.conf ]]; then
  arch=arch
fi
if [[ -z $arch && "_$(uname)" = "_Linux" ]]; then
  arch=linux
fi
if [[ -z $arch && "_$(uname)" = "_Darwin" ]]; then
  arch=mac
fi

setopt null_glob
set -x

##### Dotfiles #################################################################

# Generated, so neither a symlink nor a copy. The rest are [dotfiles] in
# mise.toml.

cat <<'EOF' > ~/.tmux.reattacher
#!/bin/sh
exec $*
EOF
chmod +x ~/.tmux.reattacher

##### git ######################################################################

git config --global ghq.root "$HOME/git"

if ! git config --global --get-regexp include.path '^~/git/config/misc/dot.gitconfig$' >/dev/null; then
  git config --global --add include.path '~/git/config/misc/dot.gitconfig'
fi

##### Homebrew (macOS) #########################################################

if [[ $arch = mac ]]; then
  if ! command -v brew >/dev/null; then
    NONINTERACTIVE=1 /bin/bash -c \
      "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
  # Put a freshly installed brew on PATH for the rest of this run.
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
  # The first cask group asks for an admin password. The `mas` entries need the
  # App Store signed in.
  brew bundle --file="$repo/Brewfile"
fi

##### Arch #####################################################################

# The mise section below installs from the repositories set up here. The
# package lists themselves are [bootstrap.packages] in mise.toml.

if [[ $arch = arch ]]; then
  if ! grep -q aur-sorah /etc/pacman.conf; then
    curl -Ssf https://sorah.jp/packaging/arch/17C611F16D92677398E0ADF51AD43CA09D82C624.txt | sudo pacman-key -a -
    sudo pacman-key --lsign-key 17C611F16D92677398E0ADF51AD43CA09D82C624
    sudo tee -a /etc/pacman.conf <<-'EOF'
[aur-sorah]
SigLevel = Required
Server = https://arch.sorah.jp/$repo/os/$arch
EOF
  fi

  # mise installs with `pacman -S --needed`, which never refreshes the sync
  # databases.
  sudo pacman -Sy

  # Conflicts with pacman:bazelisk, and --noconfirm declines the removal, which
  # fails the whole packages transaction. bazelisk also provides bazel.
  if pacman -Qq bazelisk-bin >/dev/null 2>&1; then
    sudo pacman -Rdd --noconfirm bazelisk-bin
  fi

  # ruby-build ships as a plugin directory, not a package.
  if [[ ! -e ~/.rbenv/plugins/ruby-build ]]; then
    mkdir -p ~/.rbenv/plugins
    git clone https://github.com/rbenv/ruby-build ~/.rbenv/plugins/ruby-build
  fi
fi

##### rust #####################################################################

# The mise tools phase below builds the cargo: tools in mise/tools.toml with
# this cargo.

if [[ ! -e $HOME/.rustup ]]; then
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
fi
mkdir -p ~/.zfunc
rustup_bin=$(command -v rustup || echo "$HOME/.cargo/bin/rustup")
if [[ -x $rustup_bin ]]; then
  "$rustup_bin" completions zsh > ~/.zfunc/_rustup
fi
export PATH="$HOME/.cargo/bin:$PATH"

##### mise #####################################################################

if [[ ! -x $HOME/.local/bin/mise ]]; then
  curl https://mise.run | sh
fi
export PATH="$HOME/.local/bin:$PATH"
mise settings paranoid=1

# Paranoid mode binds trust to a config's contents, so this is needed again
# after every change to mise.toml.
mise trust

# macOS app casks and the Arch pacman packages. Homebrew is not required for
# the casks, since mise manages the prefix itself.
mise bootstrap --only packages --yes

# mise refuses to overwrite a target it did not create, and a single conflict
# aborts the whole dotfiles phase, so conflicting targets are cleared first.
#
# Not --force-dotfiles: for a directory target it deletes the directory, and
# ~/.local/share/nvim/site is one.
#
# Symlink-mode targets only. Copy takes its target over whatever is there.
typeset -a mise_dotfile_links=(
  ~/.vim
  ~/.local/share/nvim/site
  ~/.vimrc
  ~/.config/nvim/init.vim
  ~/.config/nvim/coc-settings.json
  ~/.zshrc
  ~/.tmux.conf
  ~/.irbrc
  ~/.gemrc
  ~/.config/wezterm/wezterm.lua
  ~/.claude/CLAUDE.md
  ~/.claude/docs
  ~/.zshrc_global_env
  ~/.local/share/applications/sorah-browser.desktop
)
for dotfile in $mise_dotfile_links; do
  if [[ -L $dotfile && ! -e $dotfile ]]; then
    # Dangling: the source was renamed or moved. A target not declared for this
    # platform is never revisited by mise, so it would stay broken.
    rm -f -- "$dotfile"
  elif [[ -e $dotfile && ! -L $dotfile ]]; then
    # Moved aside rather than deleted: ~/.local/share/nvim/site is a directory
    # vim-plug has written into.
    mv -- "$dotfile" "$dotfile.pre-mise.$(date +%Y%m%d%H%M%S)"
  fi
done

# The tools phase skips a fragment it may not parse, so the file the dotfiles
# phase deploys is trusted before it runs.
mise bootstrap --only dotfiles --yes
mise trust "$HOME/.config/mise/conf.d/sorah-tools.toml"
# github: tools exceed the anonymous API rate limit. xtrace would print the
# token.
set +x
if [[ -z ${GITHUB_TOKEN:-} ]] && command -v gh >/dev/null && gh auth token >/dev/null 2>&1; then
  export GITHUB_TOKEN=$(gh auth token)
fi
set -x
mise bootstrap --only tools --yes

# mise's AUR backend shells out to yay, which the tools phase above installs.
if [[ $arch = arch ]]; then
  mise bootstrap packages apply --manager aur --yes
fi

##### macOS ####################################################################

if [[ $arch = mac ]]; then
  # --only runs the post-defaults hook that restarts Dock, Finder and
  # SystemUIServer. `macos defaults apply` skips hooks.
  mise bootstrap --only macos-defaults --yes

  if ! command -v pipx >/dev/null; then
    mise exec -- python -m pip install --user pipx
  fi
fi

##### go #######################################################################

# ~/.zshrc creates these too. This covers the shell this script runs in and the
# machine before its first login.
if command -v go >/dev/null || mise which go >/dev/null 2>&1; then
  [[ -d ~/.gopath ]] || mkdir ~/.gopath
  [[ -e ~/.gopath/src ]] || ln -s ../git ~/.gopath/src

  # ~/.zshrc puts ~/.gopath/bin ahead of /usr/bin and the mise shims, so a
  # `go install` binary there wins over the packaged gopls.
  rm -f ~/.gopath/bin/gopls
fi

##### claude ###################################################################

# Installs the launcher into ~/.local/bin. Explicitly bash, since the installer
# is a bash script and refuses sudo.
if ! command -v claude >/dev/null; then
  curl -fsSL https://claude.ai/install.sh | bash
  # zsh caches the directories on PATH, hiding a binary added during this run.
  rehash
fi

if command -v claude >/dev/null; then
  claude mcp get aws-knowledge-mcp-server >/dev/null 2>&1 \
    || claude mcp add -s user aws-knowledge-mcp-server -t http https://knowledge-mcp.global.api.aws
  # Re-adding an existing marketplace or plugin is an error, not a no-op.
  claude plugin marketplace add "$repo" || true
  claude plugin add sorah-spec@sorah-marketplace || true
  claude plugin marketplace add https://github.com/microsoft/playwright-cli || true
  claude plugin install playwright-cli@playwright-cli || true
fi

##### systemd ##################################################################

# The units are [bootstrap.linux.systemd.units] in mise.toml. mise installs
# them as dev.mise.<name>.service, so the bare-named copies this script used to
# install are removed first; systemd would otherwise keep running both.
if command -v systemctl >/dev/null; then
  for unit in homeproxy.service; do
    if [[ -e $HOME/.config/systemd/user/$unit ]]; then
      systemctl --user disable --now "$unit"
      rm -f -- "$HOME/.config/systemd/user/$unit"
    fi
  done
  systemctl --user daemon-reload

  mise bootstrap --only linux-systemd-units --yes
fi

set +x

if [[ $arch = mac ]]; then
  cat <<'EOF'

Done. Log out and back in for: input sources (AquaSKK/ABC), the fn key action,
and modifier-key remapping on already-connected keyboards.
EOF
else
  print "\nDone."
fi
