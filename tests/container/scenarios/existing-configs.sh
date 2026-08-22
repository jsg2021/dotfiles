# Upgrading a machine that already has hand-written dotfiles.
# stow --adopt pulls them into the repo, then install stashes them away.
source "$DOT/tests/container/scenarios/_common.sh"

printf '# my old zshrc\nexport OLD_MARKER=1\n' > "$HOME/.zshrc"
printf '" my old vimrc\n'                      > "$HOME/.vimrc"

run_install
[ "$INSTALL_STATUS" -eq 0 ] || show_install_log

suite "install still completes"
assert_eq "install exits 0" "0" "$INSTALL_STATUS"

suite "pre-existing files became links to the repo"
assert_core_links
assert_every_config_linked
assert_no_dangling_links

suite "the old content was rescued, not lost"
assert_ok "a stash entry exists" \
    bash -c "cd '$DOT' && git stash list | grep -q ."
assert_ok "the stash holds the old zshrc content" \
    bash -c "cd '$DOT' && git stash show -p | grep -q 'OLD_MARKER'"

suite "repo restored to committed state"
assert_ok "git status clean" \
    bash -c "cd '$DOT' && test -z \"\$(git status --porcelain)\""
assert_grep "repo .zshrc is the tracked one again" "ZINIT_HOME" "$DOT/configs/.zshrc"
assert_no_grep "repo .zshrc lost the adopted content" "OLD_MARKER" "$DOT/configs/.zshrc"
