#!/usr/bin/env bash
# Session-end gate: source changed but documentation did not.
# Fails OPEN (warns) if git is unavailable.
set -uo pipefail
SELF="${BASH_SOURCE[0]}"
. "$(dirname "$SELF")/_guard.sh"
studio_guard "$SELF" || exit 0
command -v git >/dev/null 2>&1 || exit 0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

CHANGED=$(git diff --name-only HEAD 2>/dev/null | grep -E "{{SOURCE_ROOTS_REGEX}}" || true)
[ -z "$CHANGED" ] && exit 0

if [ -z "$(git status --short docs/ 2>/dev/null)" ]; then
  echo "Source changed but docs/ did not. Run /handoff, or state why no doc change is needed." >&2
  exit 2
fi
exit 0
