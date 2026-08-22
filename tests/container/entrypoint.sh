#!/usr/bin/env bash
# Runs one scenario against a throwaway copy of the repo.
# The host repo is mounted read-only at /src and never modified.
set -uo pipefail

SCENARIO="${1:?usage: run-scenario <name>}"

export HOME=/root
export DOT="$HOME/.dotfiles"
export STUB_LOG=/tmp/stub.log
export DEBIAN_FRONTEND=noninteractive

# --- fresh home ------------------------------------------------------------
rm -rf "$DOT" "$HOME/.config" "$HOME/.claude" "$HOME/.local" \
       "$HOME/.zshrc" "$HOME/.vimrc" "$HOME/.gitconfig" "$HOME/.bash_profile" \
       /workspaces
: > "$STUB_LOG"

cp -a /src "$DOT"
rm -f "$DOT/.git/index.lock"

# Keep the harness's git identity out of $HOME so scenarios can assert that
# ~/.gitconfig only appears when stow puts it there.
export GIT_CONFIG_GLOBAL=/tmp/harness.gitconfig
: > "$GIT_CONFIG_GLOBAL"
git config --global user.email "test@example.invalid"
git config --global user.name  "Install Harness"
git config --global init.defaultBranch main
git config --global --add safe.directory "$DOT"

# Normalise to a clean baseline so a dirty host checkout cannot skew results.
if [ -d "$DOT/.git" ]; then
    git -C "$DOT" add -A >/dev/null 2>&1
    git -C "$DOT" commit -qm "harness baseline" >/dev/null 2>&1
else
    git -C "$DOT" init -q
    git -C "$DOT" add -A >/dev/null 2>&1
    git -C "$DOT" commit -qm "harness baseline" >/dev/null 2>&1
fi

# --- offline sandbox -------------------------------------------------------
# Stubs shadow every command that would download, install, or need root.
# Only the stubs for THIS distro's package manager are kept: leaving a `dnf`
# stub on a Debian box would send the installers down the wrong branch.
if [ "${REAL_INSTALL:-0}" != "1" ]; then
    STUB_BIN=/tmp/stub-bin
    rm -rf "$STUB_BIN"
    cp -a "$DOT/tests/stubs/bin" "$STUB_BIN"
    if command -v apt-get >/dev/null 2>&1; then
        rm -f "$STUB_BIN/dnf" "$STUB_BIN/rpm"
    else
        rm -f "$STUB_BIN/apt" "$STUB_BIN/apt-get"
    fi
    export PATH="$STUB_BIN:$PATH"
fi
# tmux plugin manager is cloned from GitHub; pretend it is already there.
mkdir -p "$HOME/.tmux/plugins/tpm"

source "$DOT/tests/lib/harness.sh"

SCENARIO_FILE="$DOT/tests/container/scenarios/$SCENARIO.sh"
if [ ! -f "$SCENARIO_FILE" ]; then
    echo "no such scenario: $SCENARIO" >&2
    echo "available:" >&2
    ls -1 "$DOT/tests/container/scenarios" | sed 's/\.sh$//;s/^/  /' >&2
    exit 2
fi

echo "### scenario: $SCENARIO   (base: $(cat /etc/os-release 2>/dev/null | awk -F= '/^PRETTY_NAME/{print $2}'))"
source "$SCENARIO_FILE"

summary
