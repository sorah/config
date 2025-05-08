#!/usr/bin/env zsh
arch=$1
if [[ -z $arch && -e /etc/pacman.conf ]]; then
  arch=arch
fi
if [[ -z $arch && "_$(uname)" = "_Linux" ]]; then
  arch=linux
fi
if [[ -z $arch && "_$(uname)" = "_Darwin" ]]; then
  arch=mac
fi

if [ "_$arch" = "_mac" ]; then
  if ! which brew; then
    echo "Install homebrew first" 1>&2
    exit 1
  fi
fi

set -x
shopt -s nullglob


ln -sfn `pwd`/vim/dot.vim ~/.vim
ln -s `pwd`/vim/dot.vim ~/.local/share/nvim/site
ln -sf `pwd`/vim/dot.vimrc ~/.vimrc
mkdir -p ~/.config/nvim
ln -sf `pwd`/vim/dot.vimrc ~/.config/nvim/init.vim
ln -sf `pwd`/vim/coc-settings.json ~/.config/nvim/coc-settings.json
ln -sf `pwd`/zsh/dot.zshrc ~/.zshrc
ln -sf `pwd`/zsh/${arch}.zshrc_global_env ~/.zshrc_global_env
ln -sf `pwd`/tmux/tmux.conf ~/.tmux.conf
ln -sf `pwd`/misc/dot.irbrc ~/.irbrc
ln -sf `pwd`/misc/dot.gemrc ~/.gemrc

mkdir -p ~/.config/wezterm; ln -sf `pwd`/wezterm.lua ~/.config/wezterm/wezterm.lua

mkdir -p ~/.local/share/applications
ln -s $(pwd)/dot.local/share/applications/sorah-browser.desktop ~/.local/share/applications/

cat <<'EOF' > ~/.tmux.reattacher
#!/bin/sh
exec $*
EOF
chmod +x ~/.tmux.reattacher
#mkdir -p ~/git/ruby/foo/{bin,lib}

git config --global ghq.root $HOME/git

if ! git config --global --get-regexp include.path '^~/git/config/misc/dot.gitconfig$' >/dev/null; then
  git config --global --add include.path '~/git/config/misc/dot.gitconfig'
fi

if [[ ! -e $HOME/.local/bin/mise ]]; then
  curl https://mise.run | bash
  eval "$($HOME/.local/bin/mise activate zsh)"
fi
mise settings paranoid=1

mise use --global terraform@latest
mise use --global aqua:astral-sh/rye
mise use --global aqua:astral-sh/uv

if [[ ! -e $HOME/.rustup ]]; then
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
fi
mkdir -p ~/.zfunc
rustup completions zsh > ~/.zfunc/_rustup

if [ "_$arch" = "_mac" ]; then
  mkdir -p `pwd`/mac/dot.config/karabiner
  ln -sf `pwd`/mac/dot.config/karabiner/karabiner.json ~/.config/karabiner/karabiner.json
  mkdir -p `pwd`/mac/dot.config/linearmouse
  ln -sf `pwd`/mac/dot.config/linearmouse/linearmouse.json ~/.config/linearmouse/linearmouse.json

  defaults write com.apple.dock workspaces-auto-swoosh -bool YES
  defaults write com.apple.dock autohide-time-modifier -float 0.5
  killall Dock

  mise use --global node@lts
  mise use --global github-cli@latest
  mise use --global python@latest
  if ! which pipx 2>/dev/null; then
    pip install --user pipx
  fi

  if ! which gsed 2>/dev/null; then
    brew install gnu-sed
  fi

  if ! which jq 2>/dev/null; then
    mise use --global aqua:jqlang/jq
  fi

  if ! which go 2>/dev/null; then
    mise use --global core:go
  fi

  if ! which tmux 2>/dev/null; then
    brew install tmux
  fi

  if ! which gpg 2>/dev/null; then
    brew install gnupg2
    brew install pinentry-mac
  fi

  if ! which fzf 2>/dev/null; then
    mise use --global aqua:junegunn/fzf@latest
  fi

  if ! which rg 2>/dev/null; then
    mise use --global aqua:BurntSushi/ripgrep
  fi

  if ! which ghq 2>/dev/null; then
    mise use --global aqua:x-motemen/ghq
  fi

  if ! which protoc 2>/dev/null; then
    mise use --global aqua:protocolbuffers/protobuf/protoc
  fi

  if ! which neovim 2>/dev/null; then
    mise use --global aqua:neovim/neovim
  fi

  if ! which cloudflared 2>/dev/null; then
    mise use --global aqua:cloudflare/cloudflared
  fi
fi

# (prioritize python installed above in macOS)
mise use --global aws-cli@latest
mise use --global gcloud@latest


if [[ "_$arch" = "_arch" ]]; then
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

  sudo pacman --needed --noconfirm -Syyu \
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
    ruby \
    python-pip \
    python-pipx \
    keychain \
    fzf \
    envchain \
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
    man-db man-pages texinfo \
    rbenv \
    amazon-ecr-credential-helper
  yay -Sy bazelisk-bin cloudflared-bin \
    perl-file-rename \
    aws-session-manager-plugin \
    pristine-tar \
    terraform-ls \
    debianutils \
    devscripts \
    git-buildpackage \
    tio \
    jsonnet-language-server-bin

  if [[ ! -e ~/.rbenv/plugins/ruby-build ]]; then
    mkdir -p ~/.rbenv/plugins
    git clone https://github.com/rbenv/ruby-build ~/.rbenv/plugins/ruby-build
  fi
fi

mise use --global pipx:aws-sam-cli

if which go 2>/dev/null >/dev/null; then
  [ ! -d ~/.gopath ] && mkdir ~/.gopath
  [ ! -d ~/.gopath/src ] && ln -s ../git ~/.gopath/src

  export GOPATH=$HOME/.gopath

  if ! which gopls; then
    go install golang.org/x/tools/gopls@latest
  fi
fi

if systemctl --version 2>/dev/null >/dev/null; then
  mkdir -p $HOME/.config/systemd/user
  for x in `pwd`/systemd/user/*; do
    cp -v "${x}" ~/.config/systemd/user/
  done
  systemctl --user daemon-reload
fi
