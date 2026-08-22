#!/usr/bin/env bash
# Parse-checks every script in the repo. Catches typos without running anything.
set -uo pipefail
REPO=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
source "$REPO/tests/lib/harness.sh"

suite "syntax: bash scripts"

while IFS= read -r script; do
    rel="${script#"$REPO"/}"
    assert_ok "bash -n $rel" bash -n "$script"
done < <(
    find "$REPO/install" "$REPO/scripts" "$REPO/tests" -type f \
        ! -name '*.zip' ! -name '*.md' ! -path '*/.git/*' -print 2>/dev/null \
    | while read -r f; do head -c 200 "$f" | grep -qE '^#!.*(bash|/sh)' && echo "$f"; done
)

suite "syntax: zsh config"

if command -v zsh >/dev/null 2>&1; then
    assert_ok "zsh -n configs/.zshrc" zsh -n "$REPO/configs/.zshrc"
    for f in vars aliases prompt; do
        assert_ok "zsh -n configs/shell/$f" zsh -n "$REPO/configs/shell/$f"
    done
else
    echo "  SKIP zsh not installed"
fi

suite "installer scripts are executable"
# They are invoked directly so their #!/bin/bash shebang applies. Losing the
# exec bit would silently fall back to whatever shell the caller was using.
while IFS= read -r script; do
    rel="${script#"$REPO"/}"
    if [ -x "$script" ]; then pass "$rel is executable"; else fail "$rel is executable" "mode $(ls -l "$script" | cut -d' ' -f1)"; fi
done < <(find "$REPO/scripts/installers" -type f ! -name helpers)
assert_ok "install is executable" test -x "$REPO/install"
assert_ok "ghostty setup.sh is executable" test -x "$REPO/configs/.config/ghostty/setup.sh"

suite "no hard-coded interpreter prefixes"
# `sh some-bash-script` silently drops every bashism in it (this broke Debian).
assert_no_grep "no 'sh \$...' invocations" \
    '(^|[^[:alnum:]_])sh +"?\$' <(cat "$REPO/install" "$REPO"/scripts/installers/* "$REPO"/scripts/installers/app/* 2>/dev/null)

suite "binary lookups go through has_binary"
# One code path for "is it installed?", so the installers-dir masking and the
# missing-`which` workaround apply everywhere.
while IFS= read -r script; do
    rel="${script#"$REPO"/}"
    code=$(mktemp)
    grep -vE '^[[:space:]]*#' "$script" > "$code"
    assert_no_grep "$rel uses has_binary, not command -v" 'command -v' "$code"
    assert_no_grep "$rel uses binary_path, not which"     '\$\(which ' "$code"
    rm -f "$code"
done < <(find "$REPO/scripts/installers" -type f ! -name helpers)

suite "syntax: misc"
assert_ok "bash -n configs/.bash_profile" bash -n "$REPO/configs/.bash_profile"
if command -v jq >/dev/null 2>&1; then
    while IFS= read -r j; do
        assert_ok "valid json ${j#"$REPO"/}" jq -e . "$j"
    done < <(find "$REPO/configs" -name '*.json' ! -path '*/nvim/*' -type f)
fi

summary
