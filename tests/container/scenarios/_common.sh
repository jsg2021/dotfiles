# Shared helpers for scenarios. Sourced, never run directly.

INSTALL_LOG=/tmp/install.log
INSTALL_STATUS=

# run_install [env assignments...] -- runs ./install from the repo root,
# capturing output to $INSTALL_LOG and the exit code to $INSTALL_STATUS.
function run_install() {
    ( cd "$DOT" && env "$@" bash ./install ) > "$INSTALL_LOG" 2>&1
    INSTALL_STATUS=$?
    echo "  (install exited $INSTALL_STATUS; log: $INSTALL_LOG)"
}

function show_install_log() {
    echo "  --- install output (tail) ---"
    tail -n 25 "$INSTALL_LOG" | sed 's/^/  | /'
    echo "  -----------------------------"
}

# The files you would notice within a minute of opening a new shell. Spelled
# out on purpose: if one of these silently stops being linked, that is a bug
# even if stow thinks the new arrangement is fine.
function assert_core_links() {
    assert_symlink    "$HOME/.zshrc"        ".dotfiles/configs/.zshrc"
    assert_symlink    "$HOME/.vimrc"        ".dotfiles/configs/.vimrc"
    assert_symlink    "$HOME/.gitconfig"    ".dotfiles/configs/.gitconfig"
    assert_symlink    "$HOME/.bash_profile" ".dotfiles/configs/.bash_profile"
    assert_links_into "$HOME/.profile"                 "/.dotfiles/configs/"
    assert_links_into "$HOME/.config/starship.toml"    "/.dotfiles/configs/"
    assert_links_into "$HOME/.config/nvim/init.lua"    "/.dotfiles/configs/"
    assert_links_into "$HOME/.config/tmux/tmux.conf"   "/.dotfiles/configs/"
    assert_links_into "$HOME/.claude/settings.json"    "/.dotfiles/configs/"
    assert_links_into "$HOME/.claude/CLAUDE.md"        "/.dotfiles/configs/"
}

# Everything else, worked out at run time so adding a config to the repo needs
# no test change. stow itself is asked what it would link -- reimplementing its
# .stow-local-ignore matching here would just be a second thing to get wrong.
#
# Pre-creating the directory skeleton in a scratch target defeats stow's
# "folding" (linking a whole directory at once), so the plan comes back as one
# line per leaf file instead of one line per top-level directory.
#
# stow_plan <repo-root>  -- prints each planned link, relative to $HOME
function stow_plan() {
    local root="$1" skel=/tmp/stow-skel

    rm -rf "$skel"
    mkdir -p "$skel"
    ( cd "$root/configs" && find . -type d ) | while read -r d; do
        mkdir -p "$skel/$d"
    done

    stow --simulate -v2 --dir="$root" --target="$skel" configs 2>&1 \
        | sed -n 's/^LINK: \(.*\) => .*/\1/p' \
        | sort
}

# assert_every_config_linked [repo-root]
function assert_every_config_linked() {
    local root="${1:-$DOT}"
    local pkg="$root/configs"
    local planned=/tmp/stow-planned.txt
    local rel total=0 missing=0 leaked=0

    stow_plan "$root" > "$planned"

    if [ ! -s "$planned" ]; then
        fail "stow has a plan for the configs package" "simulate produced no LINK lines"
        return
    fi

    while IFS= read -r rel; do
        total=$((total + 1))
        if [ "$(readlink -f "$HOME/$rel" 2>/dev/null)" != "$(readlink -f "$pkg/$rel")" ]; then
            missing=$((missing + 1))
            [ "$missing" -le 5 ] && printf '       missing: ~/%s\n' "$rel"
        fi
    done < "$planned"

    if [ "$missing" -eq 0 ]; then
        pass "every one of the $total files stow plans resolves back into the repo"
    else
        fail "every one of the $total files stow plans resolves back into the repo" \
             "$missing did not (first 5 listed above)"
    fi

    # The remainder -- whatever .stow-local-ignore held back -- must stay out of
    # $HOME, and must be there on purpose. A config that quietly stops being
    # linked because someone widened an ignore rule shows up here.
    local unexpected=0 rule matched
    while IFS= read -r rel; do
        if [ -e "$HOME/$rel" ]; then
            leaked=$((leaked + 1))
            [ "$leaked" -le 5 ] && printf '       leaked: ~/%s\n' "$rel"
        fi

        # stow always ignores its own control file.
        [ "$rel" = ".stow-local-ignore" ] && continue

        matched=0
        while IFS= read -r rule; do
            [ -z "$rule" ] && continue
            case "$rule" in \#*) continue ;; esac
            case "$rel" in "$rule"|"$rule"/*) matched=1; break ;; esac
        done < "$pkg/.stow-local-ignore"

        if [ "$matched" -eq 0 ]; then
            unexpected=$((unexpected + 1))
            [ "$unexpected" -le 5 ] && printf '       not linked, not ignored: %s\n' "$rel"
        fi
    done < <( ( cd "$pkg" && find . \( -type f -o -type l \) | sed 's|^\./||' | sort ) \
              | comm -23 - "$planned" )

    if [ "$leaked" -eq 0 ]; then
        pass "ignored configs stayed out of \$HOME"
    else
        fail "ignored configs stayed out of \$HOME" "$leaked leaked (first 5 listed above)"
    fi

    if [ "$unexpected" -eq 0 ]; then
        pass "every skipped config is covered by a .stow-local-ignore rule"
    else
        fail "every skipped config is covered by a .stow-local-ignore rule" \
             "$unexpected unaccounted for (first 5 listed above)"
    fi
}

# Anything install created must point at something real. The repo itself is
# pruned: it is a real directory under $HOME, and its contents are git's job.
function assert_no_dangling_links() {
    local broken
    broken=$(find "$HOME" -maxdepth 4 \
                  -path "$DOT" -prune -o \
                  -type l ! -exec test -e {} \; -print 2>/dev/null)
    if [ -z "$broken" ]; then
        pass "no dangling symlinks under \$HOME"
    else
        fail "no dangling symlinks under \$HOME" "$(echo "$broken" | tr '\n' ' ')"
    fi
}

# .stow-local-ignore and .stowrc must keep these out of $HOME.
function assert_ignored_not_linked() {
    assert_missing "$HOME/.stowrc"
    assert_missing "$HOME/shell"
    assert_missing "$HOME/git"
    assert_missing "$HOME/.stow-local-ignore"
}

function assert_shell_configs_parse() {
    assert_ok "zsh parses ~/.zshrc"                 zsh  -n "$HOME/.zshrc"
    assert_ok "bash parses ~/.bash_profile"         bash -n "$HOME/.bash_profile"
    assert_ok "zsh parses configs/shell/vars"       zsh  -n "$DOT/configs/shell/vars"
    assert_ok "zsh parses configs/shell/aliases"    zsh  -n "$DOT/configs/shell/aliases"
    assert_ok "zsh parses configs/shell/prompt"     zsh  -n "$DOT/configs/shell/prompt"
}
