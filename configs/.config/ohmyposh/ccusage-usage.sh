#!/usr/bin/env bash
# Emit today's Claude Code usage (cost + tokens) for an oh-my-posh `command` segment.
# Data comes from ccusage; the result is cached and refreshed in the background so the
# prompt never blocks waiting on it.
#
# ccusage is installed globally (`bun add -g ccusage`) and called directly, so there is
# no per-invocation package resolution the way `bunx ccusage` incurs.
#
# Output looks like:  $1.23 · 456k   (empty if there is no usage for today yet)

# Make sure the tools we need are reachable even from a bare non-interactive shell.
export PATH="$HOME/.bun/bin:$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:$PATH"

# Nothing to show unless Claude Code is installed.
command -v claude >/dev/null 2>&1 || exit 0

# ccusage is called directly; if it's missing, install it globally in the background
# (needs bun) and bail for now — a later prompt render will pick it up.
if ! command -v ccusage >/dev/null 2>&1; then
  command -v bun >/dev/null 2>&1 && ( bun add -g ccusage >/dev/null 2>&1 & )
  exit 0
fi

cache="${TMPDIR:-/tmp}/omp-ccusage-today.txt"
max_age=60 # seconds

refresh() {
  local today out
  today="$(date +%F)"
  out="$(ccusage daily --json 2>/dev/null \
    | jq -r --arg d "$today" '
        (.daily // []) | map(select(.period == $d)) | .[0]
        | if . == null then empty
          else
            "$" + ((.totalCost * 100 | round) / 100 | tostring)
            + " · " + ((.totalTokens / 1000) | floor | tostring) + "k"
          end')"
  # Only overwrite the cache when we actually got a value; write atomically.
  if [ -n "$out" ]; then
    printf '%s' "$out" > "$cache.tmp" && mv "$cache.tmp" "$cache"
  fi
}

# Determine cache age. `stat` flags differ between macOS (-f %m) and GNU/Linux (-c %Y).
mtime() {
  stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null || echo 0
}
age=$max_age
if [ -f "$cache" ]; then
  age=$(( $(date +%s) - $(mtime "$cache") ))
fi

# Refresh in a detached subshell if the cache is stale, then print whatever we have.
if [ "$age" -ge "$max_age" ]; then
  ( refresh >/dev/null 2>&1 & )
fi

[ -f "$cache" ] && cat "$cache"
