# A dirty checkout must abort before anything is linked or installed.
source "$DOT/tests/container/scenarios/_common.sh"

echo "scribble" >> "$DOT/README.md"

run_install

suite "guard rail"
assert_ok "install refuses to run"  bash -c "test '$INSTALL_STATUS' -ne 0"
assert_grep "explains why" "not clean" "$INSTALL_LOG"

suite "nothing was changed"
assert_missing "$HOME/.zshrc"
assert_missing "$HOME/.gitconfig"
assert_ok "no package manager calls" bash -c "test ! -s '$STUB_LOG'"
assert_grep "the local edit is untouched" "scribble" "$DOT/README.md"
