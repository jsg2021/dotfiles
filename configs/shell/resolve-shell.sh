SHELL=${SHELL:-`which bash`} # bash to be safe

function get_current_shell() {
    CURRENT_SHELL=$(basename $SHELL)
    if [ -n "$BASH_VERSION" ]; then
        CURRENT_SHELL="bash"
    elif [ -n "$ZSH_VERSION" ]; then
        CURRENT_SHELL="zsh"
    fi
    echo $CURRENT_SHELL
}

export shell=$(get_current_shell)