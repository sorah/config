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


ln -sf `pwd`/vim/dot.vim ~/.vim
ln -sf `pwd`/vim/dot.vimrc ~/.vimrc
ln -sf `pwd`/zsh/dot.zshrc ~/.zshrc
ln -sf `pwd`/zsh/${arch}.zshrc_global_env ~/.zshrc_global_env
ln -sf `pwd`/screen/dot.screenrc ~/.screenrc
ln -sf `pwd`/tmux/tmux.conf ~/.tmux.conf
ln -sf `pwd`/misc/dot.irbrc ~/.irbrc
ln -sf `pwd`/misc/dot.gemrc ~/.gemrc
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

  if ! which go 2>/dev/null; then
    brew install go
    [ ! -d ~/.gopath ] && mkdir ~/.gopath
    [ ! -d ~/.gopath/src ] && ln -s ../git ~/.gopath/src
  fi

  export GOPATH=$HOME/.gopath

  if ! which ghq; then
    go get github.com/motemen/ghq
  fi

  if ! which pyenv 2>/dev/null; then
    brew install pyenv
    pyenv install 2.7.6
    pyenv global 2.7.6
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
fi
