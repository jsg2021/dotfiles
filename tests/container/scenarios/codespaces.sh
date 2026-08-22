# GitHub Codespaces: Codespaces clones the repo to a fixed path and runs
# install from there. Configs must still be linked; OS/app installs are skipped.
source "$DOT/tests/container/scenarios/_common.sh"

CS_DIR=/workspaces/.codespaces/.persistedshare/dotfiles
mkdir -p "$(dirname "$CS_DIR")"
cp -a "$DOT" "$CS_DIR"
git -C "$CS_DIR" add -A >/dev/null 2>&1
git -C "$CS_DIR" commit -qm "codespaces baseline" >/dev/null 2>&1
git config --global --add safe.directory "$CS_DIR"

( cd "$CS_DIR" && CODESPACES=true bash ./install ) > "$INSTALL_LOG" 2>&1
INSTALL_STATUS=$?
echo "  (install exited $INSTALL_STATUS)"
[ "$INSTALL_STATUS" -eq 0 ] || show_install_log

suite "install completes in codespaces"
assert_eq "install exits 0" "0" "$INSTALL_STATUS"
assert_grep "announces codespaces mode" "codespaces" "$INSTALL_LOG"

suite "configs are linked from the codespaces checkout"
assert_symlink    "$HOME/.zshrc"     "persistedshare/dotfiles/configs/.zshrc"
assert_symlink    "$HOME/.vimrc"     "persistedshare/dotfiles/configs/.vimrc"
assert_symlink    "$HOME/.gitconfig" "persistedshare/dotfiles/configs/.gitconfig"
assert_links_into "$HOME/.config/starship.toml" "persistedshare/dotfiles/configs/"
assert_links_into "$HOME/.claude/settings.json" "persistedshare/dotfiles/configs/"

suite "stow ignore rules still apply"
assert_ignored_not_linked

suite "every config in the codespaces checkout (derived from stow's plan)"
assert_every_config_linked "$CS_DIR"
assert_no_dangling_links

suite "heavy installs were skipped"
assert_log_missing "install .*ripgrep"
assert_log_missing "1password"
assert_log_missing "install .*bat"

suite "no network clone was attempted"
assert_no_grep "did not try to clone" "Cloning into" "$INSTALL_LOG"
