#!/usr/bin/env bash
# Rewrites verbose commands so only failures return to the model.
# Fails OPEN: a broken filter must never block work.
set -uo pipefail
SELF="${BASH_SOURCE[0]}"
# shellcheck source=/dev/null
. "$(dirname "$SELF")/_guard.sh"

INPUT=$(cat)
studio_guard "$SELF" || { echo '{}'; exit 0; }

CMD="$(json_field "$INPUT" 'tool_input.command')"
[ -z "$CMD" ] && { echo '{}'; exit 0; }

# Only the noisy commands whose failures are what matter
case "$CMD" in
  "{{TEST_COMMAND}}"*|"{{BUILD_COMMAND}}"*|"{{TYPECHECK_COMMAND}}"*) ;;
  *) echo '{}'; exit 0 ;;
esac

# Never touch a command the user already piped or redirected
case "$CMD" in *\|*|*\>*) echo '{}'; exit 0 ;; esac

NEW="$CMD 2>&1 | grep -B2 -A8 -iE '(FAIL|ERROR|✕|✗|assert|Exception)' | head -150"
printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","updatedInput":{"command":"%s"}}}\n' \
  "$(json_escape "$NEW")"
