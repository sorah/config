#!/bin/bash

export LANG=en_US.UTF-8

export GTK_IM_MODULE=ibus export
XMODIFIERS=@im=ibus export
QT_IM_MODULE=ibus
ibus-daemon -drx

[[ -f ~/.Xresources ]] && xrdb -merge ~/.Xresources
if [[ -e ~/.Xmodmap ]]; then
  xmodmap ~/.Xmodmap
  xkbset m
fi
if [[ -e ~/.fehbg ]]; then
  sh ~/.fehbg &
fi

if [[ -e /usr/bin/keychain ]]; then
  eval `keychain --eval --agents ssh --systemd`
  export SSH_AUTH_SOCK
fi
if [[ -e /usr/bin/gnome-keyring-daemon ]]; then
  eval $(/usr/bin/gnome-keyring-daemon --start --components=secrets)
fi

xbindkeys

for dev in "TPPS/2 IBM TrackPoint" "pointer:Logitech USB Receiver"; do
  xinput set-prop "${dev}" "Evdev Wheel Emulation" 1
  xinput set-prop "${dev}" "Evdev Wheel Emulation Button" 2
  xinput set-prop "${dev}" "Evdev Wheel Emulation Timeout" 200
  xinput set-prop "${dev}" "Evdev Wheel Emulation Axes" 6 7 4 5
  xinput set-prop "${dev}" "Device Accel Constant Deceleration" 0.95
done

systemctl --user import-environment PATH
systemctl --user import-environment SSH_AUTH_SOCK

/usr/bin/start-pulseaudio-x11

exec i3
