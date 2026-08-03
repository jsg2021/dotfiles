#!/usr/bin/env bash
#
# push-protected.sh — temporarily relax the GitLab "main" branch protection so a
# maintainer can push directly, do the push, then restore the original rules.
#
# It changes main's *push* access level from its current value (typically
# "No one") to "Maintainers", runs `git push`, and ALWAYS restores the original
# protection afterwards via an EXIT trap — even if the push fails or you Ctrl-C.
# Merge access level and the force-push / code-owner flags are preserved.
#
# Auth + host + project are all handled by glab (the GitLab CLI): it reads the
# current repo from the origin remote and uses your `glab auth` credentials, so
# there is no token to pass in.
#
# Requirements:
#   - glab, authenticated (`glab auth login` / `glab auth status`)
#     as a user with Maintainer (or Owner) rights on the project.
#   - jq
#
# Usage:
#   ./scripts/push-protected.sh [<git push args...>]
#
# Examples:
#   ./scripts/push-protected.sh                    # push current branch's commits to configured upstream (origin)
#   ./scripts/push-protected.sh origin HEAD:main   # passes args to git push, e.g. to push a different branch or refspec 
#
# With no push args it defaults to: `git push`
#
set -euo pipefail

BRANCH="$(git rev-parse --abbrev-ref HEAD)"
PB="projects/:fullpath/protected_branches"   # glab resolves :fullpath from the repo

die() { printf 'error: %s\n' "$*" >&2; exit 1; }

command -v glab >/dev/null 2>&1 || die "glab is required (https://gitlab.com/gitlab-org/cli)"
command -v jq   >/dev/null 2>&1 || die "jq is required"
glab auth status >/dev/null 2>&1 || die "glab is not authenticated — run: glab auth login"

echo "Branch: ${BRANCH}"
echo

# --- Snapshot the current protection --------------------------------------
echo "Reading current protection for '${BRANCH}'..."
CURRENT="$(glab api "${PB}/${BRANCH}")" || die "could not read protection (is '${BRANCH}' protected?)"

ORIG_PUSH="$(jq -r '.push_access_levels[0].access_level // 0' <<<"$CURRENT")"
ORIG_MERGE="$(jq -r '.merge_access_levels[0].access_level // 40' <<<"$CURRENT")"
ORIG_FORCE="$(jq -r '.allow_force_push // false' <<<"$CURRENT")"
ORIG_CODEOWNER="$(jq -r '.code_owner_approval_required // false' <<<"$CURRENT")"

# Guard against silently clobbering a multi-rule setup (GitLab Premium can list
# several users/groups per rule). This script only round-trips a single level.
PUSH_RULES="$(jq '.push_access_levels | length' <<<"$CURRENT")"
MERGE_RULES="$(jq '.merge_access_levels | length' <<<"$CURRENT")"
if (( PUSH_RULES > 1 || MERGE_RULES > 1 )); then
  die "'${BRANCH}' has multiple push/merge rules; refusing to modify (would flatten them). Change it in the GitLab UI."
fi

level_name() {
  case "$1" in
    0)  echo "No one" ;;
    30) echo "Developers + Maintainers" ;;
    40) echo "Maintainers" ;;
    60) echo "Admins" ;;
    *)  echo "level $1" ;;
  esac
}

echo "  current push access : $(level_name "$ORIG_PUSH") ($ORIG_PUSH)"
echo "  current merge access: $(level_name "$ORIG_MERGE") ($ORIG_MERGE)"

MAINTAINER=40

# Recreate the protection with a given push access level, preserving everything else.
# GitLab has no reliable cross-version in-place edit for access levels, so we
# unprotect then re-protect.
set_push_level() {
  local level="$1"
  glab api -X DELETE "${PB}/${BRANCH}" >/dev/null
  glab api -X POST "${PB}" \
    -f "name=${BRANCH}" \
    -f "push_access_level=${level}" \
    -f "merge_access_level=${ORIG_MERGE}" \
    -f "allow_force_push=${ORIG_FORCE}" \
    -f "code_owner_approval_required=${ORIG_CODEOWNER}" >/dev/null
}

RESTORED=0
restore() {
  (( RESTORED )) && return
  RESTORED=1
  echo
  echo "Restoring push access to $(level_name "$ORIG_PUSH") ($ORIG_PUSH)..."
  if set_push_level "$ORIG_PUSH"; then
    echo "Protection restored."
  else
    echo "!! FAILED to restore protection — restore manually in GitLab:" >&2
    echo "   Settings > Repository > Protected branches > ${BRANCH} > Allowed to push: $(level_name "$ORIG_PUSH")" >&2
  fi
}

# --- Relax, push, restore -------------------------------------------------
if [[ "$ORIG_PUSH" == "$MAINTAINER" ]]; then
  echo "Push access is already 'Maintainers'; leaving protection unchanged."
else
  trap restore EXIT
  echo "Relaxing push access to 'Maintainers' (40)..."
  set_push_level "$MAINTAINER"
  echo "Done."
fi

echo
if (( $# > 0 )); then
  echo "Running: git push $*"
  git push "$@"
else
  echo "Running: git push"
  git push
fi

# EXIT trap restores the original protection (only armed if we changed it).
