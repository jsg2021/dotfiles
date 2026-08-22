# A brand new machine: nothing in $HOME, clean repo.
source "$DOT/tests/container/scenarios/_common.sh"

run_install
[ "$INSTALL_STATUS" -eq 0 ] || show_install_log

suite "install exit status"
assert_eq "install exits 0" "0" "$INSTALL_STATUS"

suite "stowed config links"
assert_core_links

suite "stow ignore rules"
assert_ignored_not_linked

suite "every config in the repo (derived from stow's own plan)"
assert_every_config_linked
assert_no_dangling_links

suite "shell configs are parseable after linking"
assert_shell_configs_parse

suite "package manager was driven"
assert_log_has "apt-get .*install .*bat|dnf .*install .*bat"
assert_log_has "install .*fzf"
assert_log_has "install .*ripgrep"
assert_log_has "install .*neovim"
assert_log_has "install .*git-delta"
assert_log_has "install .*xclip"

ARCH=$(uname -m)
case "$ARCH" in
    x86_64)  OTHER_UNAME=aarch64; WANT_MIXED=x86_64; OTHER_MIXED=arm64 ;;
    aarch64) OTHER_UNAME=x86_64;  WANT_MIXED=arm64;  OTHER_MIXED=x86_64 ;;
    *)       OTHER_UNAME='';      WANT_MIXED=$ARCH;  OTHER_MIXED='' ;;
esac

suite "binaries installed by hand (arch: $ARCH)"
assert_exists "$HOME/.local/bin/diffnav"
assert_exists "$HOME/.local/bin/diff-so-fancy"
assert_exists "$HOME/.local/bin/ghostty"
# Upstream only builds the wezterm AppImage for x86_64; other arches get a
# .deb, and nothing at all on rpm distros.
if [ "$ARCH" = "x86_64" ]; then
    assert_exists "$HOME/.local/bin/wezterm"
elif command -v apt-get >/dev/null 2>&1; then
    assert_log_has "install .*wezterm\.deb"
else
    assert_grep "wezterm skipped on $ARCH" "skipping wezterm" "$INSTALL_LOG"
    assert_missing "$HOME/.local/bin/wezterm"
fi

suite "the asset chosen matches this machine's architecture"
# The stub serves every arch a real release carries, so a filter that is not
# arch-specific would match the wrong one -- or two at once.
assert_log_has "diffnav_Linux_$WANT_MIXED\.tar\.gz"
assert_log_has "Ghostty-$ARCH\.AppImage"
if [ -n "$OTHER_UNAME" ]; then
    assert_log_missing "diffnav_Linux_$OTHER_MIXED\.tar\.gz"
    assert_log_missing "Ghostty-$OTHER_UNAME\.AppImage"
fi

suite "app installers ran"
assert_log_has "1password"
assert_log_has "gh|github"
assert_log_has "code|vscode"

suite "login shell"
assert_log_has "chsh -s .*zsh"

suite "repo left clean"
assert_ok "git status is clean after install" \
    bash -c "cd '$DOT' && git status --porcelain | tee /tmp/dirty.txt | wc -l | grep -qx 0 || { cat /tmp/dirty.txt; false; }"

suite "no stray files left in the repo"
assert_missing "$DOT/packages.microsoft.gpg"
assert_missing "$DOT/1Password.zip"
