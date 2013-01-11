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
ln -s `pwd`/misc/dot.irbrc ~/.irbrc
ln -s `pwd`/misc/dot.gemrc ~/.gemrc
mkdir -p ~/git/ruby/foo/{bin,lib}
