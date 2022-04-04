#!/bin/bash
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
ln -sf `pwd`/vim/dot.vimrc ~/.vimrc
mkdir -p ~/.config/nvim
ln -sf `pwd`/vim/dot.vimrc ~/.config/nvim/init.vim
ln -sf `pwd`/vim/coc-settings.json ~/.config/nvim/coc-settings.json
ln -sf `pwd`/zsh/dot.zshrc ~/.zshrc
ln -sf `pwd`/zsh/${arch}.zshrc_global_env ~/.zshrc_global_env
ln -sf `pwd`/tmux/tmux.conf ~/.tmux.conf
ln -sf `pwd`/misc/dot.irbrc ~/.irbrc
ln -sf `pwd`/misc/dot.gemrc ~/.gemrc
ln -sfn `pwd`/peco ~/.peco

if [ "_$arch" = "_mac" ]; then
  if ! which reattach-to-user-namespace; then
    brew install reattach-to-user-namespace
  fi

  ln -sf $(brew --prefix reattach-to-user-namespace)/bin/reattach-to-user-namespace ~/.tmux.reattacher
else
  cat <<'EOF' > ~/.tmux.reattacher
#!/bin/sh
exec $*
EOF
  chmod +x ~/.tmux.reattacher
fi
#mkdir -p ~/git/ruby/foo/{bin,lib}

git config --global ghq.root $HOME/git
git config --global ui.color auto
git config --global push.default simple

if [ ! -d ~/.vim-dein ]; then
  mkdir -p ~/.vim-dein/cache/repos/github.com/Shougo
  git clone https://github.com/Shougo/dein.vim ~/.vim-dein/cache/repos/github.com/Shougo/dein.vim
fi

if [ "_$arch" = "_mac" ]; then
  if ! which gsed 2>/dev/null; then
    brew install gnu-sed
  fi

  if ! which hg 2>/dev/null; then
    brew install mercurial
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

  #  pip install awscli
  #  pyenv rehash

  #if [ ! -e $(brew --prefix)/bin/ssh ]; then
  #  brew install homebrew/dupes/openssh
  #fi
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
  if ! grep -q aur-eagletmt /etc/pacman.conf; then
    curl https://wanko.cc/gpg-key.txt | sudo pacman-key -a -
    sudo pacman-key --lsign-key C48DBD97
    sudo tee -a /etc/pacman.conf <<-'EOF'
[aur-eagletmt]
SigLevel = Required
Server = http://arch.wanko.cc/$repo/os/$arch
EOF
  fi


  sudo pacman --needed --noconfirm -Syyu \
    base-devel \
    gnupg pinentry \
    jq \
    screen tmux zsh \
    git \
    strace \
    git mercurial subversion \
    bazel go \
    whois ipcalc iperf mtr nmap netcat tcpdump traceroute bind-tools \
    ebtables nftables \
    swaks \
    autossh \
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
    aws-cli \
    keychain \
    ffmpeg \
    osquery-bin \
    envchain \
    amazon-ecr-credential-helper
  fi

if which go 2>/dev/null >/dev/null; then
  [ ! -d ~/.gopath ] && mkdir ~/.gopath
  [ ! -d ~/.gopath/src ] && ln -s ../git ~/.gopath/src

  export GOPATH=$HOME/.gopath

  if ! which ghq; then
    go get github.com/motemen/ghq
  fi

  if ! which gopls; then
    go get golang.org/x/tools/...
  fi

  if ! which godef; then
    go get code.google.com/p/rog-go/exp/cmd/godef
  fi

  if ! which peco; then
    go get github.com/peco/peco/cmd/peco
  fi
fi

mkdir -p $HOME/.docker-compose
for x in `pwd`/docker-compose/*; do
  ln -sf "${x}" ~/.docker-compose/
done

if systemctl --version 2>/dev/null >/dev/null; then
  mkdir -p $HOME/.config/systemd/user
  for x in `pwd`/systemd/user/*; do
    cp -v "${x}" ~/.config/systemd/user/
  done
  systemctl --user daemon-reload
fi

pip3 install --user pynvim
