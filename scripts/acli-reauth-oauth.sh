#!/bin/bash
# Reset acli's stored credentials and re-authenticate with OAuth (--web).
#
# acli keeps its session in two places, and a stale entry in either one produces
# "unauthorized: use 'acli jira auth login' to authenticate" even though the config
# still looks complete:
#
#   1. ~/.config/acli/*_config.yaml  — profile + token blob
#   2. login keychain, service "acli" — go-keyring entries, acct "oauth:<cloud_id>:<account_id>"
#
# This clears both, then runs the browser OAuth flow. The config dir is backed up first.
#
# Usage: acli-reauth-oauth.sh [-y]
#   -y   skip the confirmation prompt

set -euo pipefail

CONFIG_DIR="$HOME/.config/acli"
KEYCHAIN_SERVICE="acli"
BACKUP_DIR="$CONFIG_DIR.bak-$(date +%Y%m%d-%H%M%S)"
# Cleared because all three point at the same profile; the rest of the dir is left alone.
PROFILE_FILES="global_auth_config.yaml jira_config.yaml confluence_config.yaml"

assume_yes=0
[ "${1:-}" = "-y" ] && assume_yes=1

command -v acli >/dev/null 2>&1 || { echo "✗ acli not on PATH" >&2; exit 1; }

echo "== current state =="
acli jira auth status 2>&1 | sed 's/^/   /' || true
echo

if [ "$assume_yes" -eq 0 ]; then
  echo "This will delete acli's stored credentials and start a fresh OAuth login."
  printf 'Continue? [y/N] '
  read -r reply
  case "$reply" in [yY]*) ;; *) echo "aborted"; exit 1 ;; esac
  echo
fi

# ---- 1. back up ----
if [ -d "$CONFIG_DIR" ]; then
  cp -R "$CONFIG_DIR" "$BACKUP_DIR"
  echo "✓ backed up config to $BACKUP_DIR"
else
  echo "· no $CONFIG_DIR to back up"
fi

# ---- 2. best-effort logout (no-op when the session is already dead) ----
acli jira auth logout >/dev/null 2>&1 && echo "✓ acli logout" || echo "· acli logout skipped (not authenticated)"

# ---- 3. clear keychain entries ----
# find/delete only returns one item at a time, so loop until none are left.
echo "  (macOS will ask you to authorize the keychain change — approve the dialog)"
deleted=0
for _ in 1 2 3 4 5 6 7 8 9 10; do
  acct=$(security find-generic-password -s "$KEYCHAIN_SERVICE" 2>/dev/null \
         | sed -n 's/.*"acct"<blob>="\(.*\)"/\1/p') || true
  [ -n "$acct" ] || break
  if security delete-generic-password -s "$KEYCHAIN_SERVICE" -a "$acct" >/dev/null 2>&1; then
    echo "✓ deleted keychain item: $KEYCHAIN_SERVICE / $acct"
    deleted=$((deleted + 1))
  else
    echo "✗ could not delete keychain item: $KEYCHAIN_SERVICE / $acct" >&2
    break
  fi
done
[ "$deleted" -eq 0 ] && echo "· no keychain items under service '$KEYCHAIN_SERVICE'"

# ---- 4. clear the profile configs ----
for f in $PROFILE_FILES; do
  if [ -f "$CONFIG_DIR/$f" ]; then
    rm -f "$CONFIG_DIR/$f"
    echo "✓ removed $f"
  fi
done

# ---- 5. re-authenticate ----
echo
echo "== launching OAuth login (a browser window will open) =="
if acli jira auth login --web; then
  echo
  acli jira auth status 2>&1 | sed 's/^/   /'
else
  echo
  echo "✗ OAuth login failed." >&2
  echo "  Fall back to the API token (does not expire the way OAuth does):" >&2
  echo "    printf '%s' \"\$JIRA_API_TOKEN\" | acli jira auth login \\" >&2
  echo "      --site iss-stoxx.atlassian.net --email \"\$(git config user.email)\" --token" >&2
  echo "  Restore the previous config with:" >&2
  echo "    rm -rf $CONFIG_DIR && mv $BACKUP_DIR $CONFIG_DIR" >&2
  exit 1
fi
