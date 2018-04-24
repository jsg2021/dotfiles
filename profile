export BASH_ENV=~/.bashrc
#-------------------------------------------------------------
# Source definitions (if any)
#-------------------------------------------------------------
if [ -f $BASH_ENV ]; then
      . $BASH_ENV
fi

export HISTCONTROL=erasedups
export HISTSIZE=10000
shopt -s histappend

#Setup prompt
. ~/.dotfiles/prompt

#ulimit -n 1024
ulimit -n 4096

# disable bash sessions
if [ ! -f ~/.bash_sessions_disable ]; then
    touch ~/.bash_sessions_disable
    exit 1;
fi
    
#curl https://raw.githubusercontent.com/git/git/master/contrib/completion/git-completion.bash > ~/.dotfiles/git-completion.bash
if [ -f ~/.dotfiles/git-completion.bash ]; then
  . ~/.dotfiles/git-completion.bash
fi

source ~/.dotfiles/aliases
source ~/.dotfiles/vars
