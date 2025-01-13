#!/usr/bin/env zsh
arch=$1
if [[ -z $arch && "_$(uname)" = "_Linux" ]]; then
  arch=linux
fi
if [[ -z $arch ]]; then
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
mise use --global aws-cli@latest
mise use --global aqua:astral-sh/rye
mise use --global aqua:astral-sh/uv

if [[ ! -e $HOME/.rustup ]]; then
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
fi
mkdir -p ~/.zfunc
rustup completions zsh > ~/.zfunc/_rustup

if [ "_$arch" = "_mac" ]; then
  if ! which gsed 2>/dev/null; then
    brew install gnu-sed
  fi

  if ! which jq 2>/dev/null; then
    brew install jq
  fi

  if ! which go 2>/dev/null; then
    brew install go
  fi

  if ! which tmux 2>/dev/null; then
    brew install tmux
  fi

  if ! which gpg 2>/dev/null; then
    brew install gnupg2
    brew install pinentry-mac
  fi

  if ! which fzf 2>/dev/null; then
    brew install fzf
  fi

  if ! which rg 2>/dev/null; then
    brew install ripgrep
  fi

  if ! which ghq 2>/dev/null; then
    brew install ghq
  fi
fi

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
    git \
    strace \
    git mercurial subversion \
    go go-tools \
    whois ipcalc iperf mtr nmap netcat tcpdump traceroute bind-tools \
    ebtables nftables \
    swaks \
    bridge-utils \
    curl \
    pv \
    smartmontools usbutils \
    cryptsetup btrfs-progs dosfstools lvm2 \
    dstat htop iotop lsof \
    parallel \
    imagemagick \
    ruby \
    python-pip \
    keychain \
    fzf \
    envchain \
    ripgrep \
    ghq \
    amazon-ecr-credential-helper
  yay -Sy baselisk-bin
fi

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
