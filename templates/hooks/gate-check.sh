#!/usr/bin/env bash
# Blocks source edits unless the pipeline has reached the 'create' phase.
# Fails CLOSED for protected source files, OPEN for everything else.
set -uo pipefail
SELF="${BASH_SOURCE[0]}"
# shellcheck source=/dev/null
. "$(dirname "$SELF")/_guard.sh"

INPUT=$(cat)
FILE="$(json_field "$INPUT" 'tool_input.file_path')"
[ -z "$FILE" ] && exit 0

# 1. Always writable, checked first so a broken config never blocks docs.
case "$FILE" in
  */docs/*|docs/*|*/.claude/*|.claude/*|*test*|*Test*|*spec*|*.md) exit 0 ;;
esac

# 2. Only guard the configured source roots.
PROTECTED="{{SOURCE_ROOTS_REGEX}}"
if [ -z "$PROTECTED" ] || ! printf '%s' "$FILE" | grep -qE "$PROTECTED"; then
  exit 0
fi

# 3. From here the file IS protected, so an unusable config must block.
if ! studio_guard "$SELF"; then
  echo "BLOCKED: studio is not configured; refusing to edit protected source." >&2
  exit 2
fi

GATE=".claude/state/gate.json"
if [ ! -f "$GATE" ]; then
  echo "BLOCKED: no active gate. Start the change with /feature." >&2
  exit 2
fi

PHASE="$(json_field "$(cat "$GATE")" 'phase')"
[ -z "$PHASE" ] && PHASE="idle"

case "$PHASE" in
  create|verify) exit 0 ;;
  *)
    echo "BLOCKED: gate phase is '$PHASE'. Source edits are only allowed in 'create'." >&2
    echo "Complete and approve the plan, critique and test phases first." >&2
    exit 2 ;;
esac
