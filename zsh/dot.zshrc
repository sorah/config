# sorah's zshrc
# これはUTF-8

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

# Other env-vars
export LANG=en_US.UTF-8
export LESS='-R'

#aliases
alias g=git
alias privs="screen -t privs ssh -A privs.net"
alias menheler="screen -t menheler ssh -A menheler.pasra.tk"
alias mayfield="screen -t mayfield ssh -A mayfield.privs.net"
alias stone9999="sudo stone localhost:4444 localhost:443"

export RUBY=`which ruby`

# Load other zshrc
if [[ -e ~/.zshrc_global_env ]]; then;
  source ~/.zshrc_global_env # Optimized to platform
fi
if [[ -e ~/.zshrc_env ]]; then;
  source ~/.zshrc_env # Optimized to environments
fi

# Prompt
autoload -U colors
colors

setopt prompt_subst
PROMPT="%B%{$fg[green]%}%n@%m %~ %{$fg[cyan]%}$%b%f%s%{$reset_color%} "
PROMPT2='%B%_%(?.%f.%S%F)%b %#%f%s '
SPROMPT="%r is correct? [n,y,a,e]: "
# RPROMPT="%B%{$fg[green]%}[%*]%{$reset_color%}%b"

# Shokun watashi ha hokan ga sukida
autoload -U compinit; compinit
setopt auto_pushd

# history
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt hist_ignore_dups     # ignore duplication command history list
setopt share_history        # share command history data


# Load cdd
if [[ -s ~/git/config/script/cdd ]] then
  source ~/git/config/script/cdd
  function chpwd() {
    _reg_pwd_screennum
  }
  function cdc() {
    cdd $1 && clear
  }
fi

change_window_title() { echo -ne "\ek$1\e\\" }

precmd () {
  # pwd & cmd @ screen
  if [ "$WINDOW" ]; then
    change_window_title `$RUBY -e'
    a = ENV["PWD"];

    h = File.exist?("#{ENV["HOME"]}/.zsh/cdd_pwd_list") \
      ? Hash[File.read("#{ENV["HOME"]}/.zsh/cdd_pwd_list") \
                 .split(/\r?\n/) \
                 .map{|m| x = m.split(/:/);
                          [File.expand_path(x[1..-1].join),x[0]] } \
                 .compact] \
      : nil

    if h
      n = h.select{|dir,tag| /^\d+$/ =~ tag } \
           .reject{|dir,tag| tag == ENV["WINDOW"]}
      m = h.reject{|dir,tag| /^\d+$/ =~ tag }
    end
    if (r = m[a] || n[a])
      print r
    else
      a = a.sub(ENV["HOME"],"~").split(/\//); a << "/" if a.empty?;
      print (a.size > 4 ? a[0..-2].map{|x| x[0] } << a[-1] : a).join("/")
    end
    '`
  fi
}

function preexec() {
  if [ "$WINDOW" ]; then
    change_window_title `$RUBY -e'
    a = ENV["PWD"];

    h = File.exist?("#{ENV["HOME"]}/.zsh/cdd_pwd_list") \
      ? Hash[File.read("#{ENV["HOME"]}/.zsh/cdd_pwd_list") \
                 .split(/\r?\n/) \
                 .map{|m| x = m.split(/:/);
                          [File.expand_path(x[1..-1].join),x[0]] } \
                 .compact] \
      : nil

    if h
      n = h.select{|dir,tag| /^\d+$/ =~ tag } \
           .reject{|dir,tag| tag == ENV["WINDOW"]}
      m = h.reject{|dir,tag| /^\d+$/ =~ tag }
    end
    if (r = m[a] || n[a])
      print r
    else
      a = a.sub(ENV["HOME"],"~").split(/\//); a << "/" if a.empty?;
      print (a.size > 4 ? a[0..-2].map{|x| x[0] } << a[-1] : a).join("/")
    end
    '`:`$RUBY -e"
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

# screen
if [ "$VIMSHELL" ]; then
  export PROMPT="|%m| @ %~ $ "
  export PROMPT2='%_%(?.%f.%S%F) %# '
fi

if [ ! "$TMUX" ]; then
  if [ $TERM != "screen" ]; then
    if [ ! "$VIMSHELL" ]; then
      if [ ! "$WINDOW" ]; then
        export TERM=xterm-256color
        exec screen -UxR
      fi
    fi 
  else
    if [ ! "$WINDOW" ]; then
      export TERM=xterm-256color
      exec screen -UxR
    fi
  fi 
fi

if [ "$WINDOW" ]; then
  export TERM=xterm-256color
fi


#if [[ -s ~/.rvm/scripts/rvm ]] ; then source ~/.rvm/scripts/rvm ; fi
#export GEM_HOME=~/rubies/gem


