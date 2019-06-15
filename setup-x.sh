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

if [[ "_$arch" = "_arch" ]]; then
  sudo pacman --needed --noconfirm -Syu \
    xorg-server \
    xorg-xinput xorg-xrandr xorg-xmodmap xorg-xfontsel xorg-xev \
    xorg-xinit \
    compton \
    i3-wm i3lock i3status dunst dmenu \
    xautolock xbindkeys xclip xkeycaps \
    adobe-source-han-sans-jp-fonts adobe-source-code-pro-fonts ttf-anonymous-pro ttf-dejavu ttf-droid ttf-inconsolata otf-ipafont ttf-opensans noto-fonts noto-fonts-cjk noto-fonts-extra noto-fonts-emoji ttf-ubuntu-font-family \
    rxvt-unicode urxvt-perls \
    alsa-utils pulseaudio pulseaudio-alsa  \
    gnome-keyring seahorse libsecret \
    keychain \
    ibus ibus-skk skk-jisyo \
    feh \
    mpv vlc \
    remmina \
    community/firefox-developer-edition
fi

ln -sfv $HOME/git/config/linux/x/dot.xbindkeysrc ~/.xbindkeysrc
ln -sfv $HOME/git/config/linux/x/dot.xinitrc ~/.xinitrc
ln -sfv $HOME/git/config/linux/x/dot.Xmodmap ~/.Xmodmap
ln -sfv $HOME/git/config/linux/x/dot.Xresources ~/.Xresources
ln -sfv $HOME/git/config/linux/x/i3 ~/.i3
