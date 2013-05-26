# sorah's zshrc
# この書類のエンコーディングはUTF-8

export LANG=en_US.UTF-8
export LC_CTYPE=en_US.UTF-8

# Dive into tmux
agent="$HOME/.ssh-agent-`hostname`"
if [ -S "$agent" ]; then
  export SSH_AUTH_SOCK=$agent
elif [ ! -S "$SSH_AUTH_SOCK" ]; then
  export SSH_AUTH_SOCK=$agent
elif [ ! -L "$SSH_AUTH_SOCK" ]; then
  ln -snf "$SSH_AUTH_SOCK" $agent && export SSH_AUTH_SOCK=$agent
fi

if [ ! "$TMUX" -a ! "$WINDOW" -a ! "$VIMSHELL" ]; then
  export PATH=~/brew/bin:$PATH
  export PATH=~/git/config/bin:$PATH
  export PATH=~/.rbenv/bin:$PATH
  export PATH=~/.rbenv/shims:$PATH

  if [ "$SSH_CLIENT" ]; then
    echo "set -g prefix ^X" > ~/.tmux.prefix
  else
    echo "set -g prefix ^Z" > ~/.tmux.prefix
  fi

  if tmux has-session; then
    exec tmux -2 attach
  else
    exec tmux -2
  fi
fi

if [ "$WINDOW" -o "$TMUX" ]; then
  export TERM=screen-256color
fi

# Set path in ~/git
for f in ~/git/*/*/bin
  export PATH=$f:$PATH

# Set RUBYLIB in ~/git/ruby
for f in ~/git/ruby/*/lib
do
  [[ "$HOME/git/ruby/core18/lib" = "$f" ]] && continue
  [[ "$HOME/git/ruby/ruby/lib" = "$f" ]] && continue
  [[ "$HOME/git/ruby/core2/lib" = "$f" ]] && continue
  export RUBYLIB=$RUBYLIB:$f
done

export HOSTNAME=`hostname`

# Basic path
export PATH=~/local/bin:$PATH
export PATH=~/git/config/bin:$PATH
export PATH=/usr/local/bin:$PATH
export PATH=~/sandbox/ruby/utils:$PATH
export PATH=~/rubies/bin:~/rubies/gem/bin:$PATH
export PATH=./local/bin:$PATH
export PATH=~/.gem/ruby/1.9.1/bin/:$PATH
export PATH=/usr/local/share/npm/bin:$PATH
export PATH=~/local/opt/heroku/bin:$PATH
export PATH=~/.rbenv/bin:$PATH
export PATH=~/.rbenv/shims:$PATH
eval "$(rbenv init -)"

# Other env-vars
export LESS='-R'

# server aliases
# alias privs="tmux new-window -n privs 'ssh -A privs.net'"
alias menheler="tmux new-window -n menheler 'ssh menheler.pasra.tk'"
alias mayfield="tmux new-window -n mayfield 'ssh mayfield.privs.net'"
alias linndale="tmux new-window -n linndale 'ssh linndale.privs.net'"

# don't forget to set IP addrs in /etc/hosts
alias fairfield="tmux new-window -n fairfield 'ssh fairfield-l'"
alias livermore="tmux new-window -n livermore 'ssh h.sorah.jp'"

alias be="bundle exec"
alias bi="bundle install"
alias d="git diff"
alias dc="git diff --cached"
alias s="git status -sb"
alias g="git grep"
alias b="git branch"
alias br="git name-rev --name-only HEAD"
alias ci="git commit -v"
a() { git add $*; git status -s }
m() { git commit -m "$*" }
am() { git commit -am "$*" }
alias amend="git commit --amend"
alias amem="git commit --amend -m"
alias amea="git commit --amend -a"
alias ameam="git commit --amend -am"
alias gr="git rebase"
alias gri="git rebase -i"
alias rcontinue="git rebase --continue"
alias rabort="git rebase --abort"
alias pick="git cherry-pick"
alias pcontinue="git cherry-pick --continue"
alias pabort="git cherry-pick --abort"



# Load other zshrc
if [[ -e ~/.zshrc_global_env ]]; then;
  source ~/.zshrc_global_env # Optimized to platform
fi
if [[ -e ~/.zshrc_env ]]; then;
  source ~/.zshrc_env # Optimized to environments
fi

export RUBY=`which ruby`

# Prompt
autoload -U colors
colors

setopt prompt_subst
#PROMPT="%B%{$fg[green]%}%n@%m %~ %{$fg[cyan]%}$%b%f%s%{$reset_color%} "
if [ "$SSH_CLIENT" ]; then
  PROMPT="%B%{$fg[black]%}%T %{$fg[green]%}%m %~ %{%(?.$fg[cyan].$fg[red])%}%(?.(▰╹◡╹%).ヾ(｡>﹏<｡%)ﾉﾞ)%{$reset_color%}%b "
else
  PROMPT="%B%{$fg[black]%}%T %{$fg[green]%}%~ %{%(?.$fg[cyan].$fg[red])%}%(?.(▰╹◡╹%).ヾ(｡>﹏<｡%)ﾉﾞ)%{$reset_color%}%b "
fi
PROMPT2='%B%_%(?.%f.%S%F)%b %#%f%s '
SPROMPT="%r is correct? [n,y,a,e]: "
# RPROMPT="%B%{$fg[green]%}[%*]%{$reset_color%}%b"

autoload -U compinit; compinit
setopt auto_pushd
setopt ALWAYS_TO_END
setopt AUTO_LIST
setopt COMPLETE_IN_WORD
setopt CORRECT
setopt EXTENDED_GLOB
setopt EXTENDED_HISTORY
setopt HIST_IGNORE_SPACE
setopt HIST_REDUCE_BLANKS
setopt IGNORE_EOF
setopt NO_LIST_BEEP
setopt LIST_PACKED
setopt LIST_TYPES
setopt LONG_LIST_JOBS
setopt MAGIC_EQUAL_SUBST
setopt NOTIFY
setopt NUMERIC_GLOB_SORT
setopt PRINT_EIGHT_BIT
setopt PROMPT_SUBST
setopt transient_rprompt

# history
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
#setopt hist_ignore_dups     # ignore duplication command history list
setopt share_history        # share command history data


# Load cdd
if [[ -s ~/git/config/script/cdd/cdd ]] then
  source ~/git/config/script/cdd/cdd
  function chpwd() {
    _cdd_chpwd
  }
  function cdc() {
    cdd $1 && clear
  }
fi

# change_window_title() { echo -ne "\ek$1\e\\" }
TMUX_WINDOW=`tmux display -p '#I'`
change_window_title() { tmux rename-window -t $TMUX_WINDOW "$*" }

precmd () {
  # pwd & cmd @ screen
  if [ "$WINDOW" -o "$TMUX" ]; then
    change_window_title `$RUBY ~/git/config/script/cdd_title.rb`
  fi
}

function preexec() {
  if [ "$WINDOW" -o "$TMUX" ]; then
    change_window_title `$RUBY ~/git/config/script/cdd_title.rb`:`$RUBY -e"
    print (<<-EOF.split(' ')[0])
    $1
    EOF"`
  fi
}

# Load rbtt
if [[ -s ~/git/ruby/ruby-tapper/util/zsh ]] ; then source ~/git/ruby/ruby-tapper/util/zsh ; fi

# assistme for sony cybershot
assistme() {
  mkdir -p $1/PRIVATE/SONY/GPS && wget http://control.d-imaging.sony.co.jp/GPS/assistme.dat -O $1/PRIVATE/SONY/GPS/assistme.dat
}

# notes
n() {
  vim  ~/sandbox/document/notes/"$*".mkd
}

nls() {
  ls -c ~/sandbox/document/notes | grep "$*"
}

# termtter on gdb!
termtter_gdb() {
  cd ~/local/src/ruby_trunk && gdb --directory=~/local/src/ruby_trunk --args ~/rubies/trunk/bin/ruby ~/git/ruby/termtter/bin/termtter 
}

# gnupg send keys
gpg-send() {
 gpg --keyserver pgp.mit.edu --send-keys 73E3B6AC
 gpg --keyserver pgp.nic.ad.jp --send-keys 73E3B6AC
}

mds-on() {
  sudo launchctl load -w /System/Library/LaunchDaemons/com.apple.metadata.mds.plist
}
mds-off() {
  sudo launchctl unload -w /System/Library/LaunchDaemons/com.apple.metadata.mds.plist
}


# irclog4tumblr
alias i4t="perl -e 'while(<>){s/^...... //g;s/flans/akazora/g;print;}'"

r() {
  git config --local --get-regexp "^remote\..+\.url"|sed -e 's/^remote\.\(.\{1,\}\)\.url /\1 /'
}

covspec() {
  # --save coverage.info ./spec/foo_spec.rb -- -fd -p
  bundle exec ruby -rrubygems -rbundler/setup -rrspec/autorun -S rcov -Ispec:lib $*
}



#if [[ -s ~/.rvm/scripts/rvm ]] ; then source ~/.rvm/scripts/rvm ; fi
#export GEM_HOME=~/rubies/gem

#====================
# powerup your emacs
#====================
alias emacs='vim'
