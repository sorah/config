#!/bin/bash
if [ "$1" = "" ]; then
  arch=mac
else
  arch=$1
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
if [ "$arch" = "mac" ]; then
  cd tmux/osx-pasteboard
  make
  cd ..
  ln -s `pwd`/tmux/osx-pasteboard/reattach-to-user-namespace ~/.tmux.reattacher
else
  cat <<'EOF' > ~/.tmux.reattacher
#!/bin/sh
exec $*
EOF
  chmod +x ~/.tmux.reattacher
fi
mkdir -p ~/git/ruby/foo/{bin,lib}

if [ "$arch" = "mac" ]; then
  if ! which go 2>/dev/null; then
    brew install go
  fi
fi
