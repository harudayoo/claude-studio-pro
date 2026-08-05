#!/usr/bin/env bash
# Blocks source edits unless the pipeline has reached the 'create' phase.
# Fails CLOSED: an unconfigured or unusable gate refuses source writes.
set -uo pipefail
SELF="${BASH_SOURCE[0]}"
# shellcheck source=/dev/null
. "$(dirname "$SELF")/_guard.sh"

INPUT=$(cat)
FILE="$(json_field "$INPUT" 'tool_input.file_path')"
[ -z "$FILE" ] && exit 0

# 1. Always writable, whatever the configuration state. Checked first so a
#    broken install can still be repaired — docs, specs, tests and Claude
#    config never need the gate.
case "$FILE" in
  */docs/*|docs/*|*/.claude/*|.claude/*|*test*|*Test*|*spec*|*.md) exit 0 ;;
esac

# 2. An unconfigured hook must block, and it must block HERE — before the
#    source-root test below. An unsubstituted {{SOURCE_ROOTS_REGEX}} matches
#    no path, so testing it first would silently allow every source write and
#    report success. That is the exact inversion of this hook's contract.
if ! studio_guard "$SELF"; then
  echo "BLOCKED: claude-studio is not configured, so the phase gate cannot be" >&2
  echo "  trusted. Refusing to edit source. Fill docs/setup/PROFILE.md and run" >&2
  echo "  ./configure.sh, then ./verify.sh to confirm the gate fires." >&2
  exit 2
fi

# 3. Only guard the configured source roots. Files outside them are not gated,
#    by design — that is what makes a sandbox directory usable in every phase.
PROTECTED="{{SOURCE_ROOTS_REGEX}}"
if [ -z "$PROTECTED" ] || ! printf '%s' "$FILE" | grep -qE "$PROTECTED"; then
  exit 0
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
    echo "Complete and approve the plan and test phases first." >&2
    exit 2 ;;
esac
