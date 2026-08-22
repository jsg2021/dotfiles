# The documented bootstrap: `curl -fsSL .../install | bash`.
# Two things differ from a normal run: $0 is not a real path, and the cwd is
# wherever the user happened to be standing.
source "$DOT/tests/container/scenarios/_common.sh"

( cd / && bash < "$DOT/install" ) > "$INSTALL_LOG" 2>&1
INSTALL_STATUS=$?
echo "  (piped install exited $INSTALL_STATUS)"
[ "$INSTALL_STATUS" -eq 0 ] || show_install_log

suite "piped bootstrap (README workflow)"
assert_eq "install exits 0 when piped to bash" "0" "$INSTALL_STATUS"
assert_no_grep "no 'not found' errors" "not found|No such file" "$INSTALL_LOG"

suite "configs linked despite the unknown cwd"
assert_core_links
assert_ignored_not_linked
assert_every_config_linked
assert_no_dangling_links

suite "installers still ran"
assert_log_has "install .*ripgrep"
assert_log_has "chsh -s .*zsh"
