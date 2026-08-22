# Same install, but pretending the box is the other CPU architecture.
# Catches asset filters that only happen to be right on the machine you test on.
source "$DOT/tests/container/scenarios/_common.sh"

case "$(uname -m)" in
    x86_64)  FAKE=aarch64; MIXED=arm64;  OTHER_UNAME=x86_64;  OTHER_MIXED=x86_64 ;;
    aarch64) FAKE=x86_64;  MIXED=x86_64; OTHER_UNAME=aarch64; OTHER_MIXED=arm64 ;;
    *)
        echo "  SKIP no alternate arch mapped for $(uname -m)"
        summary
        return 0
        ;;
esac

echo "  (real arch $(uname -m); pretending to be $FAKE)"
run_install FAKE_ARCH="$FAKE"
[ "$INSTALL_STATUS" -eq 0 ] || show_install_log

suite "install completes while pretending to be $FAKE"
assert_eq "install exits 0" "0" "$INSTALL_STATUS"

suite "assets picked for $FAKE, not for $(uname -m)"
assert_log_has     "diffnav_Linux_$MIXED\.tar\.gz"
assert_log_missing "diffnav_Linux_$OTHER_MIXED\.tar\.gz"
assert_log_has     "Ghostty-$FAKE\.AppImage"
assert_log_missing "Ghostty-$OTHER_UNAME\.AppImage"

suite "wezterm follows the arch, not the AppImage default"
if [ "$FAKE" = "x86_64" ]; then
    assert_log_has "WezTerm-Ubuntu20\.04\.AppImage"
elif command -v apt-get >/dev/null 2>&1; then
    # Upstream ships no arm AppImage, so it must fall back to the .deb.
    assert_log_has     "wezterm-.*arm64\.deb"
    assert_log_missing "WezTerm-Ubuntu20\.04\.AppImage"
else
    # rpm distro on arm: no build exists at all, so skip rather than install
    # an x86_64 AppImage.
    assert_grep "wezterm skipped on $FAKE" "skipping wezterm" "$INSTALL_LOG"
    assert_log_missing "WezTerm-Ubuntu20\.04\.AppImage"
fi

suite "configs still land"
assert_core_links
assert_every_config_linked
