export BASH_ENV=~/.bashrc
#-------------------------------------------------------------
# Source definitions (if any)
#-------------------------------------------------------------
if [ -f $BASH_ENV ]; then
      . $BASH_ENV
fi


export VIRTUAL_ENV=/opt/local/
export WORKSPACE_DIR=~/Workspace

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

alias gl='git log --graph --oneline'

alias serverlog='tail -f $WORKSPACE_DIR/buildout/var/log/pserve-stderr*'
alias n='ps | grep '"'"'[n]ode'"'"''

alias spp='git stash;git pull -r;git stash pop'

alias ww='cd $WORKSPACE_DIR/nti-web-app'
alias mm='cd $WORKSPACE_DIR/nti-web-mobile'

export HISTCONTROL=erasedups
export HISTSIZE=10000
shopt -s histappend

export NTI_BUILDOUT_PATH=$WORKSPACE_DIR/buildout/
export NTI_BIN=$WORKSPACE_DIR/buildout/bin/

#export CFLAGS="-I/opt/local/include -L/opt/local/lib"
#export EDITOR="/usr/local/bin/mate -w"

export PATH=/opt/local/bin:/opt/local/sbin:$PATH

export PATH=~/.dotfiles/scripts:$PATH
export PATH=.:$PATH
export PATH=./node_modules/.bin:$PATH

export ANDROID_HOME=~/Library/Android/sdk
export PATH=$PATH:${ANDROID_HOME}/tools
