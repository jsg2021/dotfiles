#!/bin/bash
# Re-authenticate acli to Jira and Confluence with an Atlassian API token.
#
# Why a token and not OAuth (--web): OAuth rotates its refresh token on every refresh,
# and session-brief runs a dozen acli calls in parallel. Whenever a run coincided with
# a refresh, the calls raced on the token and the session died. A token never rotates.
#
# acli has three separate logins; this script sets the two product ones:
#
#   acli jira auth …        ~/.config/acli/jira_config.yaml        keychain acct "jira:…"
#   acli confluence auth …  ~/.config/acli/confluence_config.yaml  keychain acct "confluence:…"
#   acli auth …             global OAuth, no --token option. Left empty on purpose, so
#                           `acli auth status` reporting "unauthorized" is expected.
#                           Logging into it can rewrite the product profiles to OAuth.
#
# --clean wipes stored credentials first. Use it when a login reports success but
# commands still fail: acli keeps state both in the yaml profiles and in the login
# keychain (service "acli"), and a stale entry in either survives a plain re-login.
#
# The token comes from $ACLI_API_TOKEN, else $JIRA_API_TOKEN, and the email from
# $JIRA_EMAIL (default: the ISS address). The token is piped on stdin so it never
# appears in argv. Atlassian tokens expire (1-365 days); make a new one at
# https://id.atlassian.com/manage-profile/security/api-tokens.
#
# Usage: acli-reauth.sh [--clean] [-y]
#   --clean  delete acli's keychain items and profile configs before logging in
#   -y       skip the confirmation prompt

set -euo pipefail

SITE="iss-stoxx.atlassian.net"
CONFIG_DIR="$HOME/.config/acli"
KEYCHAIN_SERVICE="acli"
BACKUP_DIR="$CONFIG_DIR.bak-$(date +%Y%m%d-%H%M%S)"
PRODUCTS="jira confluence"
# All three can point at the same profile, so --clean clears all of them.
PROFILE_FILES="global_auth_config.yaml jira_config.yaml confluence_config.yaml"

assume_yes=0
clean=0
for arg in "$@"; do
  case "$arg" in
    -y) assume_yes=1 ;;
    --clean) clean=1 ;;
    -h|--help) sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "✗ unknown argument: $arg" >&2; exit 2 ;;
  esac
done

command -v acli >/dev/null 2>&1 || { echo "✗ acli not on PATH" >&2; exit 1; }

TOKEN="${ACLI_API_TOKEN:-${JIRA_API_TOKEN:-}}"
[ -n "$TOKEN" ] || { echo "✗ set ACLI_API_TOKEN or JIRA_API_TOKEN" >&2; exit 1; }
# Not git's user.email: the global one is a personal address, and acli answers a
# token paired with the wrong email with a bare "Unauthorized".
EMAIL="${JIRA_EMAIL:-jonathan.grimes@iss-stoxx.com}"

echo "== current state =="
for p in $PRODUCTS; do
  echo "  $p:"
  acli "$p" auth status 2>&1 | sed 's/^/    /' || true
done
echo

if [ "$assume_yes" -eq 0 ]; then
  if [ "$clean" -eq 1 ]; then
    echo "This will delete acli's stored credentials, then log in to $SITE as $EMAIL with an API token."
  else
    echo "This will log acli in to $SITE as $EMAIL with an API token."
  fi
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

# ---- 2. optional wipe ----
if [ "$clean" -eq 1 ]; then
  for p in $PRODUCTS; do
    acli "$p" auth logout >/dev/null 2>&1 && echo "✓ $p logout" || echo "· $p logout skipped (not authenticated)"
  done

  # find/delete only returns one item at a time, so loop until none are left.
  echo "  (macOS may ask you to authorize the keychain change — approve the dialog)"
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

  for f in $PROFILE_FILES; do
    if [ -f "$CONFIG_DIR/$f" ]; then
      rm -f "$CONFIG_DIR/$f"
      echo "✓ removed $f"
    fi
  done
fi

restore_hint() {
  [ -d "$BACKUP_DIR" ] || return 0
  echo "  Restore the previous config with:" >&2
  echo "    rm -rf $CONFIG_DIR && mv $BACKUP_DIR $CONFIG_DIR" >&2
}

# ---- 3. log in ----
echo
for p in $PRODUCTS; do
  # Captured because acli draws a spinner; only shown when the login fails.
  if out=$(printf '%s' "$TOKEN" | acli "$p" auth login --site "$SITE" --email "$EMAIL" --token 2>&1); then
    echo "✓ $p login"
  else
    echo "✗ $p login failed:" >&2
    # The spinner shares a line with the error; keep only the error text.
    { printf '%s\n' "$out" | grep -oE 'Error:.*' || printf '%s\n' "$out" | tail -1; } \
      | sed 's/^/    /' >&2
    echo "  Check JIRA_EMAIL ($EMAIL). An expired or revoked token also fails here;" >&2
    echo "  make a new one at" >&2
    echo "  https://id.atlassian.com/manage-profile/security/api-tokens" >&2
    restore_hint
    exit 1
  fi
done

# ---- 4. verify with real reads (auth status alone can pass on a dead session) ----
echo
failed=0
if acli jira workitem search --jql "assignee = currentUser()" --limit 1 --json >/dev/null 2>&1; then
  echo "✓ jira read"
else
  echo "✗ jira read failed" >&2; failed=1
fi
if acli confluence space list --limit 1 --json >/dev/null 2>&1; then
  echo "✓ confluence read"
else
  echo "✗ confluence read failed" >&2; failed=1
fi

if [ "$failed" -eq 1 ]; then
  [ "$clean" -eq 0 ] && echo "  Logged in but a read failed; re-run with --clean." >&2
  restore_hint
  exit 1
fi
