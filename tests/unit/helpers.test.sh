#!/usr/bin/env bash
# Unit tests for scripts/installers/helpers. No network, no package manager.
set -uo pipefail
REPO=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
source "$REPO/tests/lib/harness.sh"

# helpers sets -e; turn it back off so a failing assert does not kill the run.
source "$REPO/scripts/installers/helpers"
set +e

suite "map_get"
BINARY_PKG_ALIASES=("rg ripgrep" "nvim neovim" "delta git-delta")
assert_eq "aliased key returns package"      "ripgrep"  "$(map_get rg "${BINARY_PKG_ALIASES[@]}")"
assert_eq "second aliased key"               "neovim"   "$(map_get nvim "${BINARY_PKG_ALIASES[@]}")"
assert_eq "unknown key passes through"       "fzf"      "$(map_get fzf "${BINARY_PKG_ALIASES[@]}")"
assert_eq "distro override map wins"         "fd-find"  "$(map_get fd "fd fd-find")"

suite "has_binary"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
printf '#!/bin/sh\nexit 0\n' > "$TMP/dotfiles-fake-tool"
chmod +x "$TMP/dotfiles-fake-tool"

OLD_PATH="$PATH"
PATH="$TMP:$PATH"

INSTALLERS_DIR="/nonexistent-dir"
assert_ok    "finds a real binary on PATH"            has_binary ls
assert_ok    "finds the fake tool when dir not masked" has_binary dotfiles-fake-tool
assert_fails "does not find a nonexistent binary"      has_binary dotfiles-definitely-not-here

INSTALLERS_DIR="$TMP"
assert_fails "ignores binaries inside the installers dir" has_binary dotfiles-fake-tool
assert_ok    "still finds binaries elsewhere on PATH"     has_binary ls

PATH="$OLD_PATH"

suite "is_git_clean"
CLEAN=$(mktemp -d)
git -C "$CLEAN" init -q
git -C "$CLEAN" config user.email t@t.test
git -C "$CLEAN" config user.name test
echo hi > "$CLEAN/a"
git -C "$CLEAN" add a
git -C "$CLEAN" commit -qm init
assert_ok "clean repo reports clean" bash -c "cd '$CLEAN' && source '$REPO/scripts/installers/helpers' && is_git_clean"
echo changed > "$CLEAN/a"
assert_fails "modified file reports dirty" bash -c "cd '$CLEAN' && source '$REPO/scripts/installers/helpers' && is_git_clean"
git -C "$CLEAN" checkout -q -- a
echo new > "$CLEAN/untracked"
assert_fails "untracked file reports dirty" bash -c "cd '$CLEAN' && source '$REPO/scripts/installers/helpers' && is_git_clean"
rm -rf "$CLEAN"

NOTREPO=$(mktemp -d)
assert_ok "non-repo counts as clean" bash -c "cd '$NOTREPO' && source '$REPO/scripts/installers/helpers' && is_git_clean"
rm -rf "$NOTREPO"

suite "arch_for"
# arch_for reads `uname -m`; a shell function shadows the real binary.
function uname() { echo "$FAKE_ARCH"; }

FAKE_ARCH=x86_64
assert_eq "intel  -> uname" "x86_64" "$(arch_for uname)"
assert_eq "intel  -> go"    "amd64"  "$(arch_for go)"
assert_eq "intel  -> mixed" "x86_64" "$(arch_for mixed)"

FAKE_ARCH=aarch64
assert_eq "linux arm -> uname" "aarch64" "$(arch_for uname)"
assert_eq "linux arm -> go"    "arm64"   "$(arch_for go)"
assert_eq "linux arm -> mixed" "arm64"   "$(arch_for mixed)"

FAKE_ARCH=arm64
assert_eq "mac arm -> uname" "arm64" "$(arch_for uname)"
assert_eq "mac arm -> go"    "arm64" "$(arch_for go)"
assert_eq "mac arm -> mixed" "arm64" "$(arch_for mixed)"

FAKE_ARCH=armv7l
assert_eq "armv7 -> go" "arm" "$(arch_for go)"

FAKE_ARCH=riscv64
assert_eq "unknown arch passes through" "riscv64" "$(arch_for go)"

assert_fails "an unknown flavour is an error" arch_for sideways

unset -f uname

suite "get_distro_id"
assert_ok "returns something" bash -c "source '$REPO/scripts/installers/helpers' && test -n \"\$(get_distro_id)\""

summary
