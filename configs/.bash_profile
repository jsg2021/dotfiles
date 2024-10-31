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


#ulimit -n 1024
ulimit -n 4096

# disable bash sessions
if [ ! -f ~/.bash_sessions_disable ]; then
    touch ~/.bash_sessions_disable
    exit 1;
fi
    
export shell=bash

#curl https://raw.githubusercontent.com/git/git/master/contrib/completion/git-completion.bash > ~/.dotfiles/git-completion.bash
[ -f ~/.dotfiles/configs/git/completion.bash ] && source ~/.dotfiles/configs/git/completion.bash
source ~/.dotfiles/configs/shell/vars
source ~/.dotfiles/configs/shell/aliases

#Setup prompt
source ~/.dotfiles/configs/shell/prompt