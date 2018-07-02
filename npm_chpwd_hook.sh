# Adds node_modules/.bin to the PATH

npm_chpwd_echo () {
    command printf %s\\n "$*" 2>/dev/null
}

npm_chpwd_strip_path () {
    npm_chpwd_echo $PATH | command sed -e "s#${1}:##g"
}

npm_chpwd_hook() {
    if [ -n "${PRE_BIN+x}" ]; then
        PATH="$(npm_chpwd_strip_path "$PRE_BIN")"
        unset PRE_BIN
    fi
    NPM=$(which npm)
    if [ -n "$NPM" ]; then
        BIN=$(npm bin)
        if [ -n "$BIN" ]; then
            PRE_BIN=$BIN
            PATH=$BIN:$PATH
        fi
    fi
}

add-zsh-hook precmd npm_chpwd_hook
