#!/usr/bin/env zsh
#
# All-in-one machine setup. Idempotent: safe to re-run.
#
#   ./setup.sh [mac|arch|linux]
#
# The declarative half lives in mise.toml (macOS app casks, macOS preferences,
# the dotfiles) and mise/tools.toml (the global tool set), and is applied from
# here through `mise bootstrap`. The Brewfile keeps what Homebrew still owns:
# casks whose installers need sudo, the formulae, and the Mac App Store apps.
# See README.md.
#
# Deliberately no `set -e`: one failing step should not strand the rest of the
# run. Re-run after fixing whatever failed.

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

# Generated, so neither a symlink nor a copy of anything -- the rest of the
# dotfiles are [dotfiles] in mise.toml, applied further down.

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
  # The first cask group asks for an admin password; the `mas` entries need the
  # App Store signed in.
  brew bundle --file="$repo/Brewfile"
fi

##### mise #####################################################################

if [[ ! -x $HOME/.local/bin/mise ]]; then
  curl https://mise.run | sh
fi
export PATH="$HOME/.local/bin:$PATH"
mise settings paranoid=1

# Paranoid mode binds trust to a config's contents, so this is needed again
# after every change to mise.toml.
mise trust

# macOS app casks. Homebrew is not required for these: mise manages the prefix
# itself.
mise bootstrap --only packages --yes

# mise refuses to overwrite a target it did not create, and a single conflict
# aborts the whole dotfiles phase, so conflicting targets are cleared first.
# Both branches are guarded on the state they fix, so this is a no-op on a
# migrated machine and on a fresh one.
#
# --force-dotfiles would cover this in one flag, but for a directory target it
# deletes the directory, and ~/.local/share/nvim/site is one.
#
# Symlink-mode targets only: copy takes its target over whatever is there.
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

# The global tool set is declared in mise/tools.toml and deployed to
# ~/.config/mise/conf.d/ by a [dotfiles] entry. Deploy, trust -- the tools phase
# skips a fragment it may not parse -- then install.
mise bootstrap --only dotfiles --yes
mise trust "$HOME/.config/mise/conf.d/sorah-tools.toml"
mise bootstrap --only tools --yes

##### rust #####################################################################

if [[ ! -e $HOME/.rustup ]]; then
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
fi
mkdir -p ~/.zfunc
rustup_bin=$(command -v rustup || echo "$HOME/.cargo/bin/rustup")
if [[ -x $rustup_bin ]]; then
  "$rustup_bin" completions zsh > ~/.zfunc/_rustup
fi

##### macOS ####################################################################

if [[ $arch = mac ]]; then
  # UI preferences live in mise.toml. Run via --only so the post-defaults hook
  # restarts Dock/Finder/SystemUIServer; `macos defaults apply` skips hooks.
  mise bootstrap --only macos-defaults --yes

  if ! command -v pipx >/dev/null; then
    mise exec -- python -m pip install --user pipx
  fi
fi

##### Arch #####################################################################

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

  mise use --global asdf:mise-plugins/mise-yay

  # https://unix.stackexchange.com/questions/274727/how-to-force-pacman-to-answer-yes-to-all-questions/584001#584001
  sudo pacman --needed --noconfirm --ask 54 -Syy \
    base-devel \
    gnupg pinentry \
    jq \
    screen tmux zsh \
    neovim \
    git \
    strace \
    git mercurial subversion \
    go go-tools \
    whois ipcalc iperf mtr nmap netcat tcpdump traceroute bind-tools wireguard-tools ethtool ldns \
    inetutils \
    ebtables nftables \
    swaks \
    bridge-utils \
    curl \
    pv \
    smartmontools usbutils \
    cryptsetup btrfs-progs dosfstools lvm2 xfsprogs \
    e2fsprogs \
    dool htop iotop lsof \
    parallel \
    imagemagick \
    ruby ruby-irb ruby-erb \
    nodejs \
    python-pip \
    python-pipx \
    keychain \
    fzf \
    ripgrep \
    ghq \
    github-cli \
    protobuf \
    patatt \
    mold \
    file findutils grep lsof \
    zip \
    cmake \
    openssl cfssl \
    cosign \
    man-db man-pages texinfo \
    postgresql-libs mariadb-clients \
    rbenv \
    docker-buildx \
    amazon-ecr-credential-helper
  # yay comes from mise just above, so it is not on PATH yet on a fresh box.
  mise exec -- yay -Sy bazelisk-bin cloudflared-bin \
    perl-file-rename \
    aws-session-manager-plugin \
    pristine-tar \
    terraform-ls \
    debianutils \
    devscripts \
    git-buildpackage \
    tio \
    envchain \
    overmind \
    jsonnet-language-server-bin

  if [[ ! -e ~/.rbenv/plugins/ruby-build ]]; then
    mkdir -p ~/.rbenv/plugins
    git clone https://github.com/rbenv/ruby-build ~/.rbenv/plugins/ruby-build
  fi
fi

##### go #######################################################################

if command -v go >/dev/null || mise which go >/dev/null 2>&1; then
  [[ -d ~/.gopath ]] || mkdir ~/.gopath
  [[ -e ~/.gopath/src ]] || ln -s ../git ~/.gopath/src

  export GOPATH=$HOME/.gopath

  # `which gopls` misses it whenever GOPATH/bin is off PATH, which would
  # reinstall on every run.
  if [[ ! -x $GOPATH/bin/gopls ]]; then
    mise exec -- go install golang.org/x/tools/gopls@latest
  fi
fi

##### claude ###################################################################

# Installs the launcher into ~/.local/bin, already on PATH from the mise
# section. Explicitly bash: the installer is a bash script and refuses sudo.
if ! command -v claude >/dev/null; then
  curl -fsSL https://claude.ai/install.sh | bash
  # zsh caches the contents of the directories on PATH, so a binary added to
  # one during this run stays invisible to the block below without this.
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

if command -v systemctl >/dev/null; then
  mkdir -p "$HOME/.config/systemd/user"
  for x in "$repo"/systemd/user/*; do
    cp -v "$x" "$HOME/.config/systemd/user/"
  done
  systemctl --user daemon-reload
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
