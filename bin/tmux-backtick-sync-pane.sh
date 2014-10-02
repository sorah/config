#!/bin/sh
[ "_$(tmux show-window-options synchronize-panes)" = "_synchronize-panes on" ] && echo " SYNC "
