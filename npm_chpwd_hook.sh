# Adds node_modules/.bin to the PATH
# https://gist.github.com/puffnfresh/4151775
npm_chpwd_hook() {
    if [ -n "${PRENPMPATH+x}" ]; then
        PATH=$PRENPMPATH
        unset PRENPMPATH
    fi
    NPM=$(which npm)
    if [ -n "$NPM" ]; then
        BIN=$(npm bin)
        if [ -n "$BIN" ]; then
            PRENPMPATH=$PATH
            PATH=$BIN:$PATH
        fi
    fi
}

add-zsh-hook preexec npm_chpwd_hook
