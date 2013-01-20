#!/bin/sh
if [ "$1" = "" ]; then
  arch=mac
else
  arch=$1
fi

ln -s `pwd`/vim/dot.vim ~/.vim
ln -s `pwd`/vim/dot.vimrc ~/.vimrc
ln -s `pwd`/zsh/dot.zshrc ~/.zshrc
ln -s `pwd`/zsh/${arch}.zshrc_global_env ~/.zshrc_global_env
ln -s `pwd`/screen/dot.screenrc ~/.screenrc
ln -s `pwd`/tmux/tmux.conf ~/.tmux.conf
ln -s `pwd`/misc/dot.irbrc ~/.irbrc
ln -s `pwd`/misc/dot.gemrc ~/.gemrc
if [ "$arch" = "mac" ]; then
  ln -s `pwd`/tmux/osx-pasteboard/reattach-to-user-namespace ~/.tmux.reattacher
else
  cat <<'EOF' > ~/.tmux.reattacher
#!/bin/sh
exec $*
EOF
  chmod +x ~/.tmux.reattacher
fi
mkdir -p ~/git/ruby/foo/{bin,lib}
