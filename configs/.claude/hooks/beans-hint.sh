#!/bin/sh
# UserPromptSubmit hook: point sessions at an existing beans task store.
#
# Same reasoning as graphify-hint.sh: the CLAUDE.md section describing beans is
# prose the model may or may not act on, and there is no skill to trigger at
# all. This runs in the harness on every prompt instead, so the reminder is not
# optional. Stays silent in projects with no beans db.
#
# Wired up in ~/.claude/settings.json.

root="${CLAUDE_PROJECT_DIR:-$PWD}"

# Stand down when the project checks in its own copy of this hook, so the hint is
# injected once rather than twice. Projects without a copy still rely on this one.
[ -f "$root/.claude/hooks/beans-hint.sh" ] && exit 0

# beans finds its db by walking up from the working directory — do the same, so
# a session started in a subdirectory still gets the hint.
dir="$root"
db=""
while [ -n "$dir" ] && [ "$dir" != "/" ]; do
	if [ -f "$dir/.beans/beans.db" ]; then
		db="$dir/.beans/beans.db"
		break
	fi
	dir=$(dirname "$dir")
done

# No store here — say nothing rather than advertising a tracker with no data.
[ -n "$db" ] || exit 0

# A db with no CLI to read it is worth flagging once, not silently ignoring.
if ! command -v beans >/dev/null 2>&1; then
	printf '%s\n' "This project has a beans task store at ${db#"$dir"/} but \`beans\` is not on PATH, so it cannot be read. Mention this if the user asks about tracked work; do not fall back to guessing at their task list."
	exit 0
fi

# The trap from CLAUDE.md: a registry entry for this repo in the global config
# silently overrides the local db, so writes appear to vanish. Only warn when
# an entry actually names this path.
override=""
config="${XDG_CONFIG_HOME:-$HOME/.config}/beans/config.json"
if [ -f "$config" ] && grep -qF "$dir" "$config" 2>/dev/null; then
	override=" WARNING: \`$config\` has a registry entry naming this repo, which silently overrides the local db — reads and writes may be hitting the global store instead. Check that before trusting any bean state."
fi

# Surface how much unblocked work is waiting, so the reminder is actionable
# rather than a standing instruction with nothing behind it.
# Run from the store's own directory — beans resolves the db by walking up from
# its cwd, and the hook's cwd is not necessarily inside this repo.
ready=$(cd "$dir" && beans --json ready 2>/dev/null | grep -o '"id":' | wc -l | tr -d ' ')
[ -n "$ready" ] || ready="an unknown number of"

printf '%s\n' "This project tracks work items in beans (${db#"$dir"/}), with $ready unblocked item(s) ready. Read them with \`beans --json ready\` and \`beans --json show <id>\` before picking up or proposing work — a bean body is written to stand alone, so it is the authority on scope and on what \"done\" means. Claim before starting (\`beans claim <id> --actor <name>\`) and close with a reason (\`beans close <id> --reason \"...\"\`). \`.beans/AGENTS.md\` beside the db is the authority on bean hygiene — read it before creating or editing one. Always pass \`--json\` so output is parseable. Skip all of this for questions that are not about tracked work.${override}"
