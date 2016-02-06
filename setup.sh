#!/bin/bash
if [ "$1" = "" ]; then
  arch=mac
else
  arch=$1
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
ln -sf `pwd`/zsh/dot.zshrc ~/.zshrc
ln -sf `pwd`/zsh/${arch}.zshrc_global_env ~/.zshrc_global_env
ln -sf `pwd`/screen/dot.screenrc ~/.screenrc
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

  if ! which autossh 2>/dev/null; then
    brew install autossh
  fi

  if ! which pyenv 2>/dev/null; then
    brew install pyenv
    pyenv install 2.7.10
    pyenv global 2.7.10
  fi

  eval "$(pyenv init -)"

  if ! which percol; then
    pip install percol
    pyenv rehash
  fi

  if ! which aws; then
    pip install awscli
    pyenv rehash
  fi

  if ! which aws-shell; then
    pip install aws-shell
    pyenv rehash
  fi

  if ! which circusd; then
    pip install circus
    pyenv rehash
  fi

  if [ ! -d ~/.nginx ]; then
    mkdir ~/.nginx
  fi

  if ! which nginx; then
    brew tap homebrew/nginx
    brew install --devel nginx-full --with-auth-req --with-dav-ext-module --with-geoip --with-gunzip --with-gzip-static --with-headers-more-module --with-lua-module --with-mp4 --with-mp4-h264-module --with-pcre-jit --with-push-stream-module --with-realip --with-rtmp-module --with-spdy --with-status --with-sub --with-webdav
  fi

  reload_launchd_nginx=0
  if [[ ! -d /etc/nginx ]]; then
    sudo mkdir /etc/nginx
  fi
  if [[ ! -e /etc/nginx/mime.types ]]; then
    sudo cp $(brew --prefix)/etc/nginx/mime.types /etc/nginx/mime.types
    reload_launchd_nginx=1
  fi
  if [[ ! -e /etc/nginx.conf ]] || [[ nginx/local.80.conf -nt /etc/nginx.conf ]]; then
    sudo cp nginx/local.80.conf /etc/nginx.conf
    sudo chown root:wheel /etc/nginx.conf
    sudo chmod 644 /etc/nginx.conf
    reload_launchd_nginx=1
  fi
  if [[ ! -e /Library/LaunchDaemons/jp.sorah.launchagent.nginx.plist ]] || [[ nginx/jp.sorah.launchagent.nginx.plist -nt /Library/LaunchDaemons/jp.sorah.launchagent.nginx.plist ]]; then
    sudo cp nginx/jp.sorah.launchagent.nginx.plist /Library/LaunchDaemons/jp.sorah.launchagent.nginx.plist
    sudo chown root:wheel /Library/LaunchDaemons/jp.sorah.launchagent.nginx.plist
    sudo chmod 644 /Library/LaunchDaemons/jp.sorah.launchagent.nginx.plist
    reload_launchd_nginx=1
  fi
  if [ "_${reload_launchd_nginx}" = "_1" ]; then
    sudo launchctl unload -w /Library/LaunchDaemons/jp.sorah.launchagent.nginx.plist || :
    sudo launchctl load -w /Library/LaunchDaemons/jp.sorah.launchagent.nginx.plist
  fi

  ln -sf `pwd`/circus/circus.ini ~/.circus.ini
  if [ ! -d ~/.circus ]; then
    mkdir ~/.circus
  fi
  for x in `pwd`/circus/*.ini; do
    [ "${x##*/}" = "circus.ini" ] && continue
    ln -sf $x ~/.circus/
  done
fi

if which go 2>/dev/null >/dev/null; then
  [ ! -d ~/.gopath ] && mkdir ~/.gopath
  [ ! -d ~/.gopath/src ] && ln -s ../git ~/.gopath/src

  export GOPATH=$HOME/.gopath

  if ! which ghq; then
    go get github.com/motemen/ghq
  fi

  if ! which gocode; then
    go get github.com/nsf/gocode
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
