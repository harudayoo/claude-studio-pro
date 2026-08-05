#!/usr/bin/env bash
# Formats and type-checks the edited file so defects surface in the same turn.
# Fails OPEN.
set -uo pipefail
SELF="${BASH_SOURCE[0]}"
# shellcheck source=/dev/null
. "$(dirname "$SELF")/_guard.sh"

INPUT=$(cat)
studio_guard "$SELF" || exit 0

FILE="$(json_field "$INPUT" 'tool_input.file_path')"
[ -f "$FILE" ] || exit 0

case "$FILE" in
  {{FORMAT_GLOB}}) {{FORMAT_COMMAND}} "$FILE" >/dev/null 2>&1 || true ;;
esac

case "$FILE" in
  {{TYPECHECK_GLOB}}) {{TYPECHECK_COMMAND}} 2>&1 | grep -F "$FILE" | head -20 || true ;;
esac
exit 0
