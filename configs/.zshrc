export ZSH=~/.dotfiles/oh-my-zsh
ZSH_CUSTOM=~/.dotfiles/zsh/

DISABLE_UPDATE_PROMPT=true
# COMPLETION_WAITING_DOTS="true"
DISABLE_UNTRACKED_FILES_DIRTY="true"


plugins=(
  git
  fnm
  fzf
  zsh-autosuggestions
  # zsh-syntax-highlighting must be last
  zsh-syntax-highlighting
)

source ~/.dotfiles/configs/shell/vars
source $ZSH/oh-my-zsh.sh

source ~/.dotfiles/configs/shell/prompt
source ~/.dotfiles/configs/shell/aliases

setopt hist_ignore_all_dups
setopt hist_expire_dups_first
setopt hist_save_no_dups
setopt hist_find_no_dups
setopt hist_no_store
setopt hist_no_functions
setopt hist_reduce_blanks


bindkey -e # use the Emacs editing mode.

autoload zmv
autoload -Uz url-quote-magic bracketed-paste-magic
zle -N self-insert url-quote-magic
zle -N bracketed-paste bracketed-paste-magic

typeset -U PATH #deduplicate path elements
