#!/usr/bin/env bash
# Emit Claude Code usage for the oh-my-posh Claude segment (a `text` segment reads the
# result via $CCUSAGE_TODAY). Three things are reported, kept compact:
#
#   1. Today's totals   —  cost + tokens spent so far today.
#   2. Context usage    —  how full the latest session's context window is (%), which
#      ccusage computes with the correct window size (200k vs the 1M beta).
#   3. Time to reset    —  time left in the current 5-hour rate-limit window.
#
# Data comes from ccusage; the result is cached and refreshed in the background so the
# prompt never blocks waiting on it. oh-my-posh honours color tags embedded in the env
# var value, so the context % is colored green/yellow/red as the window fills.
#
# ccusage is installed globally (`bun add -g ccusage`) and called directly, so there is
# no per-invocation package resolution the way `bunx ccusage` incurs.
#
# Output looks like:  $1.23 456k 6% 2h6m
# (empty if there is no usage for today yet)

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
  local today today_out latest sid sl ctx left color seg out
  today="$(date +%F)"

  # 1. Today's totals: "$1.23 · 456k" (empty if there's no usage for today yet).
  today_out="$(ccusage daily --json 2>/dev/null \
    | jq -r --arg d "$today" '
        (.daily // []) | map(select(.period == $d)) | .[0]
        | if . == null then empty
          else
            "$" + ((.totalCost * 100 | round) / 100 | tostring)
            + " " + (if .totalTokens >= 1000000
                       then ((.totalTokens / 1000000 * 10 | round) / 10 | tostring) + "M"
                       else ((.totalTokens / 1000) | floor | tostring) + "k" end)
          end')"

  # 2 + 3. Context % and time-to-reset both come from `ccusage statusline`, which expects
  #        the session JSON that Claude Code normally pipes to its statusline hook. We feed
  #        it the most-recently-updated transcript; ccusage reads it for the real figures
  #        (and picks the right context-window size — 200k vs the 1M beta — on its own).
  latest="$(command ls -t "$HOME"/.claude/projects/*/*.jsonl 2>/dev/null | head -1)"
  ctx=""; left=""
  if [ -n "$latest" ]; then
    sid="$(basename "$latest" .jsonl)"
    sl="$(jq -nc --arg s "$sid" --arg t "$latest" \
            '{session_id:$s, transcript_path:$t, cwd:".", model:{id:"claude-opus-4-8", display_name:"Opus"}, workspace:{current_dir:"."}}' \
          | ccusage statusline 2>/dev/null)"
    # Context is the last "(NN%)"; block reset is the last "(… left)".
    ctx="$(printf '%s' "$sl" | grep -oE '\([0-9]+%\)' | tail -1 | tr -dc '0-9')"
    left="$(printf '%s' "$sl" | grep -oE '\([0-9hm ]+ left\)' | tail -1 | sed -E 's/[()]//g; s/ *left//; s/ //g')"
  fi

  out="$today_out"

  # Context %, colored by how full the window is (green <50, yellow <80, red >=80).
  if [ -n "$ctx" ]; then
    if   [ "$ctx" -ge 80 ]; then color=red
    elif [ "$ctx" -ge 50 ]; then color=yellow
    else color=green
    fi
    seg="<$color>${ctx}%</>"
    [ -n "$out" ] && out="$out $seg" || out="$seg"
  fi

  # Time left in the current 5-hour rate-limit window.
  if [ -n "$left" ]; then
    [ -n "$out" ] && out="$out $left" || out="$left"
  fi

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
