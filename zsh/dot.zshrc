# sorah's zshrc
# この書類のエンコーディングはUTF-8
# vim: ft=zsh

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

run_tmux=1
[[ -n "$NOTMUX" ]] && run_tmux=0
[[ -n "$TMUX" ]] && run_tmux=0
[[ -n "$WINDOW" ]] && run_tmux=0
[[ "_$TERM" = "_linux" ]] && run_tmux=0

if [ "_$run_tmux" = "_1" ]; then
  # minimal path
  export SORAH_ORIG_PATH=$PATH
  export PATH=$HOME/brew/bin:$HOME/brew/sbin:/opt/brew/bin:/opt/brew/sbin:$PATH
  export PATH=~/git/config/bin:$PATH
  if [ -e /usr/share/rbenv ]; then
    export PATH=/usr/share/rbenv/bin:/usr/share/rbenv/shims:$PATH
  else
    export PATH=$HOME/.rbenv/bin:$HOME/.rbenv/shims:$PATH
  fi
  export PATH=~/.cargo/bin:$PATH

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
[ ! -d ~/.gopath ] && mkdir ~/.gopath
[ ! -d ~/.gopath/src ] && ln -s ../git ~/.gopath/src
export GOPATH=$HOME/.gopath
export GO111MODULE=on

export HOSTNAME=`hostname`

# Basic path
if [[ -n $SORAH_ORIG_PATH ]]; then
  export PATH=$SORAH_ORIG_PATH
  unset SORAH_ORIG_PATH
fi
export PATH=$HOME/brew/bin:$HOME/brew/sbin:/opt/brew/bin:/opt/brew/sbin:$PATH
export PATH=$HOME/local/bin:$PATH
export PATH=$HOME/.local/bin:$PATH
export PATH=$HOME/git/config/bin:$PATH
export PATH=/usr/local/bin:$PATH
export PATH=/usr/local/share/npm/bin:$PATH
export PATH="$HOME/.yarn/bin:$PATH"
#export PATH=/usr/share/nodebrew/current/bin:$HOME/.nodebrew/current/bin:$PATH
alias npm-exec='PATH=$(npm bin):$PATH'
alias ne='PATH=$(npm bin):$PATH'

if [ -e /usr/share/rbenv ]; then
  export PATH=/usr/share/rbenv/shims:/usr/share/rbenv/bin:$PATH
else
  export PATH=$HOME/.rbenv/shims:$HOME/.rbenv/bin:$PATH
fi
rbenv_uninit_path=$PATH
eval "$(rbenv init --no-rehash -)"
export PATH=$rbenv_uninit_path

if [[ -e /opt/asdf-vm/asdf.sh ]]; then
  . /opt/asdf-vm/asdf.sh
fi

export PATH=~/.cargo/bin:$PATH

export PATH=~/.plenv/bin:$PATH
if command -v plenv >/dev/null 2>&1; then
  eval "$(plenv init -)"
fi

if command -v docker-machine >/dev/null 2>&1; then
  eval "$(docker-machine env default 2>/dev/null)"
fi

export GEMSRC_USE_GHQ=1
export DISABLE_SPRING=1

export BUNDLE_JOBS=300
export BUNDLE_FORCE_RUBY_PLATFORM=true

if which pyenv > /dev/null; then eval "$(pyenv init --no-rehash -)"; fi
if [[ -e  "$HOME/.rye/env" ]]; then
  export RYE_NO_AUTO_INSTALL=1
  source "$HOME/.rye/env"
fi

export PATH=~/.gopath/bin:$PATH

# export PATH=~/local/opt/heroku/bin:$PATH
export PATH=~/local/opt/google-cloud-sdk/bin:$PATH
export PATH=~/local/opt/packer:$PATH
export PATH=~/local/opt/istio/bin:$PATH
export PATH=~/local/opt/go/bin:$PATH
# export PATH="/usr/local/heroku/bin:$PATH"

export CLOUDSDK_PYTHON=/usr/bin/python

#export RUST_SRC_PATH=$(rustc --print sysroot 2>/dev/null)/lib/rustlib/src/rust/src

export BROWSER=$HOME/git/config/bin/sorah-browser

# Other env-vars
export LESS='-R'

alias utc='TZ=Etc/UTC date'

# server aliases
alias menheler="tmux new-window -n menheler 'ssh menheler.pasra.tk'"

nkmish() {
  name=$1
  shift
  tmux new-window -n $name "ssh $* ${name}.c.nkmi.me"
}
nkmish-i() {
  name=$1
  shift
  ssh "$@" ${name}.c.nkmi.me
}


alias e="envchain "
eb() {
  local ns
  ns=$1
  shift
  envchain "${ns}" bundle exec "$@"
}

alias rka="mairu exec --server rubykaigi 'arn:aws:iam::005216166247:role/OrgzAdmin' "
export MAIRU_AGENT_LOG=mairu=debug

alias ms="nkmish"
alias msi="nkmish-i"

alias be="bundle exec "
alias bi="bundle install "
alias d="git diff"
alias dc="git diff --cached"
alias s="git status -sb"
alias g="git grep"
alias b="git branch"
alias br="git name-rev --name-only HEAD"
alias ci="GPG_TTY=\$(tty) git commit -v"
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
r() {
  git config --local --get-regexp "^remote\..+\.url"|sed -e 's/^remote\.\(.\{1,\}\)\.url /\1 /'
}

brm() {
  local origin br
  if git remote -v|grep -q '^sorah'; then
    origin=sorah
  else
    origin=origin
  fi
  for br in $@; do
    git branch -D $br
    git push --delete $origin $br
  done
}

zsorah_ruby_path=`which ruby`
if [[ -d "$(rbenv root 2>/dev/null)" ]]; then
  zsorah_ruby_path="zsorah-ruby"
fi
zsorah-ruby() { RBENV_DIR=$HOME RBENV_VERSION="$(rbenv global)" ruby "$@" }

# Prompt
autoload -U colors
colors

setopt prompt_subst
#PROMPT="%B%{$fg[green]%}%n@%m %~ %{$fg[cyan]%}$%b%f%s%{$reset_color%} "

set_prompt() {
  local face
  face=${1:-$current_face}
  current_face=${face}
  if [[ -n "$SORAH_PROMPT_HOSTNAME" ]]; then
    PROMPT="%B%{$fg[black]%}%T %{$fg[green]%}${SORAH_PROMPT_HOSTNAME} %~ %{%(?.$fg[cyan].$fg[red])%}$face%{$reset_color%}%b "
  elif [[ -n "$SSH_CLIENT" ]]; then
    PROMPT="%B%{$fg[black]%}%T %{$fg[green]%}%m %~ %{%(?.$fg[cyan].$fg[red])%}$face%{$reset_color%}%b "
  else
    PROMPT="%B%{$fg[black]%}%T %{$fg[green]%}%~ %{%(?.$fg[cyan].$fg[red])%}$face%{$reset_color%}%b "
  fi
  if [[ "_$SORAH_COMPACT" = "_1" ]]; then
    PROMPT="%B%{%(?.$fg[cyan].$fg[red])%}$face%{$reset_color%}%b "
  fi
}
sorah-prompt-face-a() {
  set_prompt "%(?.(▰╹◡╹%).(.>﹏<%))"

}
sorah-prompt-face-b() {
  set_prompt "%(?.(▰╹◡╹%).ヾ(｡>﹏<｡%)ﾉﾞ)"
}
sorah-prompt-face-c() {
  set_prompt '%(?.(▰╹◡╹%).(▰╹o╹%))'
}

sorah-prompt-face-a
#if [ -n "$SSH_CLIENT" ]; then
#  sorah-prompt-face-b
#fi

PROMPT2='%B%_%(?.%f.%S%F)%b %#%f%s '
SPROMPT="%r is correct? [n,y,a,e]: "
# RPROMPT="%B%{$fg[green]%}[%*]%{$reset_color%}%b"

RPROMPT='%{$fg[black]%}$(rbenv version | grep -v "set by ${RBENV_ROOT}/version" | sed -e "s/(set by RBENV_VERSION.*$/shell/" -e "s/(set by.*$/local/" | sed -e "s/^/[rb /" -e "s/$/]/" )%{$reset_color%}'

sorah-compact-on() {
  SORAH_COMPACT=1
}

sorah-compact-off() {
  SORAH_COMPACT=0
}

autoload -U +X bashcompinit && bashcompinit
autoload -U +X compinit && compinit
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

set -o emacs

# history
HISTFILE=~/.zsh_history
HISTSIZE=200000
SAVEHIST=10000000
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
change_window_title() { tmux rename-window -t "$TMUX_PANE" "$*" }

OKO_COUNT=0

precmd() {
  if [[ "_${SORAH_ZSHRC_LOADED}" = "_1" ]]; then
    if [[ $? = "0" ]];then
      OKO_COUNT=0
    else
      let OKO_COUNT+=1
    fi

    #if [ 1 -le "$OKO_COUNT" ]; then
    #  set_prompt "ヾ(｡>﹏<｡)ﾉﾞ"
    #elif [ 0 -le "$OKO_COUNT" ]; then
    #  set_prompt "(▰╹◡╹)"
    #fi
    set_prompt

    # pwd & cmd @ screen
    if [[ -n "$TMUX" ]]; then
      change_window_title "$($zsorah_ruby_path --disable-gems ~/git/config/script/cdd_title.rb)"
    fi
  fi
}

function preexec() {
  if [[ "_${SORAH_ZSHRC_LOADED}" = "_1" ]]; then
    if [[ -n "$TMUX" ]]; then
      change_window_title "$($zsorah_ruby_path --disable-gems ~/git/config/script/cdd_title.rb):$(echo "$1"|cut -d' ' -f 1)"
    fi
  fi
}

# gnupg send keys
gpg-send() {
for srv in pgp.mit.edu pgp.nic.ad.jp; do
  for keyid in 73E3B6AC 31604EB9 F4C0895C 3F0F56A8; do
    gpg --keyserver $srv --send-keys $keyid
  done
done
}

gpg-preset() {
  ruby -rio/console -e '$stderr.print "Passphrase:"; puts($stdin.noecho { $stdin.gets }); $stderr.puts'| /usr/libexec/gpg-preset-passphrase --preset $1
}

mds-on() {
  sudo launchctl load -w /System/Library/LaunchDaemons/com.apple.metadata.mds.plist
}
mds-off() {
  sudo launchctl unload -w /System/Library/LaunchDaemons/com.apple.metadata.mds.plist
}

##
# $ gcd     -> launch peco for `ghq list` then cd to selection
# $ gcd x/x -> chdir to ~/git/x/x or ~/git/github.com/x/x
gcd() {
  if [[ -n "$1" ]]; then
    candidate=~/git/$1
    [[ ! -d "$candidate" ]] && candidate=~/git/github.com/$1
    cd $candidate
  else
    candidate=$(ghq list | peco)
    [[ -z "${candidate}" ]] && return 1
    cd ~/git/${candidate}
  fi
}

alias cssh="tmux-nested-cssh"
mycssh() {
  tmux-nested-cssh -n my-cssh --ssh-option=-t -c 'env TMUX=1 zsh' \
    oakland.her livermore.her hilliard.her \
    boston.her ashley.her linndale.her \
    lakewood.her
}

new-repo() {
  repo=${NEW_REPO_PREFIX:-github.com/sorah}/$1
  mkdir -p $repo
  gcd $repo
  git init
}

new-gem() {
  gcd ${NEW_REPO_PREFIX:-github.com/sorah}
  bundle gem --mit --no-coc $1
  cd $1
}

set-git-author-private() {
  git config user.email 'her@sorah.jp'
}

main() {
  local default
  default="$(git symbolic-ref refs/remotes/origin/HEAD | sed -e 's|^.\+/||')"
  echo "${default}"
  git checkout "$@" "${default}"
}
alias master=main

### aws

if [ "$(uname)" = "Darwin" ]; then
  aws_wrapper="envchain aws"
fi

aws-instances-by-name() {
  local iname
  iname=$1
  shift
  ${=aws_wrapper} aws ec2 describe-instances "$@" --filters "Name=tag:Name,Values=$iname"
}

aws-instance-ids-by-name() {
  aws-instances-by-name "$@" --output json | jq -r '.Reservations[] | .Instances[] | .InstanceId'
}

aws-public-dns-names-by-ids() {
  ${=aws_wrapper} aws ec2 describe-instances --output json --instance-ids "$@" | awsi_filter-public-dns-name
}

aws-public-dns-names-by-names() {
  aws-instances-by-name "$@" | awsi_filter-public-dns-name
}

aws-ssh-public-dns-by-name() {
  local iname dnsname
  iname=$1
  shift
  dnsname="$(aws-public-dns-names-by-names $iname | head -n1)"
  echo $dnsname
  ssh "$@" $dnsname
}

awsi_filter-public-dns-name() {
  jq -r '.Reservations[] | .Instances[] | .PublicDnsName'
}

pull-pics() {
  mkdir -p ~/pictures
  rsync -avi americano.home.her:Dropbox/Photos/Tumbletail ~/pictures
  rsync -avi americano.home.her:Dropbox/Photos/Pixitail ~/pictures
}

cop() {
  local base range
  base=$1
  if [[ -z $base ]]; then
    if git diff --name-only | grep -q .; then
      base=HEAD
      range=HEAD
    else
      base=master
    fi
  fi
  if [[ -z $range ]]; then
    range="${base}...HEAD"
  fi
  echo "${range}"
  ( 
    set -x
    git diff --name-only --diff-filter=d "${range}" -- '*.rb' '*.iam' | xargs bundle exec rubocop --auto-correct   
  )
}

yaml2json() {
  ruby -ryaml -rjson -e 'YAML.load_stream($stdin) {|_| puts _.to_json }' | jq .
}

yaml2jsona() {
  ruby -ryaml -rjson -e 'a = []; YAML.load_stream($stdin) {|_| a << _ }; puts a.to_json' | jq .
}

jl() {
  jq --color-output "$@" | less -R
}
yl() {
  yaml2json | jl "$@"
}

alias k=kubectl
if which kubectl >/dev/null 2>/dev/null; then
  source <(kubectl completion zsh)
  complete -F __start_kubectl k
fi

alias tf=terraform
export TF_PLUGIN_CACHE_DIR=$HOME/.terraform.d/plugin-cache
if [[ ! -e "$TF_PLUGIN_CACHE_DIR" ]]; then
  mkdir -p $TF_PLUGIN_CACHE_DIR
fi

#====================
# powerup your emacs
#====================
alias emacs='vim'
alias vim='DISPLAY= nvim'

timecurl() {
  curl -w "@$HOME/git/config/etc/curl-timing.txt" "$@"
}

sorah-docker-ensure() {
  if [[ -z "$(docker image ls -q $1)" ]]; then
    docker build -t $1 -f ~/git/config/docker/Dockerfile.$1 ~/git/config/docker
  else
    echo "(to update, run: docker image rm $1)"
  fi
  tag=$1
  shift
  if [[ "_$1" = "__" ]]; then
    shift
    docker run --rm "$@"
  else
    docker run --rm "${tag}" "$@"
  fi
}

if ! which apt-get >/dev/null 2>/dev/null; then
  alias apt='sorah-docker-ensure eix-ubuntu apt'
  alias apt-get='sorah-docker-ensure eix-ubuntu apt-get'
  alias apt-cache='sorah-docker-ensure eix-ubuntu apt-cache'
fi
if ! which gbp >/dev/null 2>/dev/null; then
  gbp() {
    reponame=$(basename "${PWD}")
    sorah-docker-ensure gbp _ -ti --net=host -u $(id -u):$(id -g) -e HOME=/home/sorah -v "${HOME}/.gitconfig:/home/sorah/.gitconfig:ro" -v "$(realpath ${PWD}/../):/git" -w /git/${reponame} gbp gbp "$@"
  }
fi
if ! which dch >/dev/null 2>/dev/null; then
  sorah-devscripts() {
    reponame=$(basename "${PWD}")
    sorah-docker-ensure devscripts _ -ti --net=host -u $(id -u):$(id -g) -e HOME=/home/sorah -v "$(realpath ${PWD}/../):/git" -w /git/${reponame} devscripts "$@"
  }
  alias dch='sorah-devscripts dch'
  alias debsign='sorah-devscripts debsign'
fi

# Load other zshrc
if [[ -e ~/.zshrc_global_env ]]; then;
  source ~/.zshrc_global_env # Optimized to platform
fi
if [[ -e ~/.zshrc.env ]]; then;
  source ~/.zshrc.env # Optimized to environments
fi
if [[ -e ~/.zshrc_env ]]; then;
  source ~/.zshrc_env # Optimized to environments
fi


export RBENV_ROOT=${RBENV_ROOT:-$HOME/.rbenv}
SORAH_ZSHRC_LOADED=1
