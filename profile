export BASH_ENV=~/.bashrc
#-------------------------------------------------------------
# Source definitions (if any)
#-------------------------------------------------------------
if [ -f $BASH_ENV ]; then
      . $BASH_ENV
fi


export VIRTUAL_ENV=/opt/local/


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

#alias listings to color and details
alias ls='ls -l -GFh'
alias ll='ls -lt'
alias grep='grep --colour=auto'

alias serverlog='tail -f ~/Workspace/buildout/var/log/pserve-stderr*'
alias n='ps | grep '"'"'[n]ode'"'"''

alias spp='git stash;git pull -r;git stash pop'

alias ww='cd ~/Workspace/nti-web-app'
alias mm='cd ~/Workspace/nti-web-mobile'

export HISTCONTROL=erasedups
export HISTSIZE=10000
shopt -s histappend

export NTI_BUILDOUT_PATH=~/Workspace/buildout/
export NTI_BIN=~/Workspace/buildout/bin/

#export CFLAGS="-I/opt/local/include -L/opt/local/lib"
#export EDITOR="/usr/local/bin/mate -w"

export PATH=/opt/local/bin:/opt/local/sbin:$PATH

export PATH=~/.dotfiles/scripts:$PATH
export PATH=.:$PATH
export PATH=./node_modules/.bin:$PATH

export ANDROID_HOME=~/Library/Android/sdk
export PATH=$PATH:${ANDROID_HOME}/tools
