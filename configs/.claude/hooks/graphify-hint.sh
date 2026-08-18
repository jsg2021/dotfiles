#!/bin/sh
# UserPromptSubmit hook: point sessions at an existing graphify graph.
#
# The graphify skill's own trigger is its `description` field, which is a
# judgment call the model makes per prompt — so it silently doesn't fire.
# This runs in the harness on every prompt instead, so the reminder is not
# optional. Stays silent in projects with no graph built.
#
# Wired up in .claude/settings.local.json (gitignored, so it stays local).

root="${CLAUDE_PROJECT_DIR:-$PWD}"

# Stand down when the project checks in its own copy of this hook, so the hint is
# injected once rather than twice. Projects without a copy still rely on this one.
[ -f "$root/.claude/hooks/graphify-hint.sh" ] && exit 0
graph="$root/graphify-out/graph.json"

# No graph here — say nothing rather than advertising a tool with no data.
[ -f "$graph" ] || exit 0

# Flag a graph older than the newest commit, so it is used knowing it's stale
# rather than trusted blindly.
stale=""
if command -v git >/dev/null 2>&1 && git -C "$root" rev-parse --git-dir >/dev/null 2>&1; then
	committed=$(git -C "$root" log -1 --format=%ct 2>/dev/null)
	built=$(stat -f %m "$graph" 2>/dev/null || stat -c %Y "$graph" 2>/dev/null)
	if [ -n "$committed" ] && [ -n "$built" ] && [ "$committed" -gt "$built" ]; then
		stale=' NOTE: the graph predates the newest commit — treat it as stale, and run `graphify update .` before relying on it.'
	fi
fi

printf '%s\n' "A graphify knowledge graph is built for this project at graphify-out/graph.json. For questions about this codebase — architecture, what calls what, where something lives, how data flows — run \`graphify query \"<question>\"\` first and answer from the graph, citing source_location. Use Grep/Read/Explore to fall back or to verify what the graph returns. Skip this for non-codebase questions and for edits to a file already in context.${stale}"
