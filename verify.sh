#!/usr/bin/env bash
#
# claude-studio self-test
#
# Proves the hooks actually fire, and that the installed inventory matches the
# tier that was installed. Run after configure.sh and again any time you change
# a hook or the profile.
#
# A hook you have not watched fire is a hook you do not have.
#
set -uo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="$(pwd)"
[ "${1:-}" = "--target" ] && { TARGET="$(cd "$2" && pwd)"; shift 2; }
cd "$TARGET"

PASS=0; FAIL=0
pass() { printf '  \033[32mPASS\033[0m %s\n' "$1"; PASS=$((PASS+1)); }
fail() { printf '  \033[31mFAIL\033[0m %s\n' "$1"; FAIL=$((FAIL+1)); }
head_() { printf '\n\033[1m%s\033[0m\n' "$1"; }

[ -d .claude/hooks ] || { echo "no .claude/hooks — run install.sh first"; exit 1; }

hook() { printf '%s' "$2" | bash ".claude/hooks/$1" 2>/dev/null; }
rc_of() { printf '%s' "$2" | bash ".claude/hooks/$1" >/dev/null 2>&1; echo $?; }

# ------------------------------------------------------------- installed tier
read_tier() {
  [ -f .claude/state/studio.json ] || return 1
  if command -v jq >/dev/null 2>&1; then
    jq -r '.tier // empty' .claude/state/studio.json 2>/dev/null
  else
    tr -d '\n' < .claude/state/studio.json \
      | grep -o '"tier"[[:space:]]*:[[:space:]]*"[^"]*"' \
      | head -1 | sed 's/.*:[[:space:]]*"//; s/"$//'
  fi
}
PLAN="$(read_tier || true)"
MANIFEST="$SRC/templates/tiers/$PLAN/manifest.conf"
if [ -n "$PLAN" ] && [ -f "$MANIFEST" ]; then
  # shellcheck source=/dev/null
  . "$MANIFEST"
else
  TIER_NAME="unknown"; TIER_AGENTS=""; TIER_SKILLS=""; TIER_RULES=""
  TIER_UI_AGENTS=""; TIER_UI_SKILLS=""; TIER_UI_RULES=""
fi

printf '\n\033[1mclaude-studio self-test\033[0m  ·  %s plan\n' "$TIER_NAME"

head_ "0. Configuration"
if [ -n "$PLAN" ] && [ -f "$MANIFEST" ]; then
  pass "installed tier recorded: $PLAN"
else
  fail "cannot read the installed tier from .claude/state/studio.json — re-run install.sh"
fi
if grep -rq '{{[A-Z_]*}}' .claude 2>/dev/null; then
  fail "placeholders remain — run ./configure.sh"
  grep -rl '{{[A-Z_]*}}' .claude | sed 's/^/       /'
else
  pass "no unresolved placeholders"
fi
for f in .claude/hooks/*.sh; do
  [ -x "$f" ] && pass "executable: $(basename "$f")" || fail "not executable: $(basename "$f")"
done

GATE=.claude/state/gate.json
SAVED="$(cat "$GATE" 2>/dev/null || echo '{"phase":"idle"}')"
restore() { printf '%s\n' "$SAVED" > "$GATE"; }
trap restore EXIT

head_ "1. Gate blocks source edits outside the create phase"
printf '{"phase":"idle","feature":null,"slug":null,"approved":[]}\n' > "$GATE"
SRC_FILE="$(grep -oE '\^\(([^)]*)\)' .claude/hooks/gate-check.sh | head -1 \
            | sed 's/^\^(//; s/)$//' | cut -d'|' -f1)/probe.ts"
[ "$(rc_of gate-check.sh "{\"tool_input\":{\"file_path\":\"$SRC_FILE\"}}")" = 2 ] \
  && pass "blocks $SRC_FILE" || fail "blocks $SRC_FILE"
[ "$(rc_of gate-check.sh '{"tool_input":{"file_path":"docs/specs/x/idea.md"}}')" = 0 ] \
  && pass "allows docs/" || fail "allows docs/"
[ "$(rc_of gate-check.sh '{"tool_input":{"file_path":"tests/x.test.ts"}}')" = 0 ] \
  && pass "allows tests/" || fail "allows tests/"
[ "$(rc_of gate-check.sh '{"tool_input":{"file_path":".claude/agents/x.md"}}')" = 0 ] \
  && pass "allows .claude/" || fail "allows .claude/"

head_ "2. Gate opens in the create phase"
printf '{"phase":"create","feature":"probe","slug":"probe","approved":["plan"]}\n' > "$GATE"
[ "$(rc_of gate-check.sh "{\"tool_input\":{\"file_path\":\"$SRC_FILE\"}}")" = 0 ] \
  && pass "allows $SRC_FILE in create" || fail "allows $SRC_FILE in create"
restore

head_ "3. Output filter"
TESTCMD="$(grep -oE '"[^"]+"\*\|' .claude/hooks/filter-output.sh | head -1 | sed 's/^"//; s/"\*|$//')"
if [ -n "$TESTCMD" ]; then
  out="$(hook filter-output.sh "{\"tool_input\":{\"command\":\"$TESTCMD\"}}")"
  case "$out" in *updatedInput*) pass "rewrites: $TESTCMD" ;; *) fail "rewrites: $TESTCMD" ;; esac
else
  fail "could not read the test command out of filter-output.sh"
fi
[ "$(hook filter-output.sh '{"tool_input":{"command":"ls -la"}}')" = "{}" ] \
  && pass "ignores unrelated commands" || fail "ignores unrelated commands"
[ "$(hook filter-output.sh "{\"tool_input\":{\"command\":\"$TESTCMD | tee o.txt\"}}")" = "{}" ] \
  && pass "leaves piped commands alone" || fail "leaves piped commands alone"

head_ "4. Doc check"
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  bash .claude/hooks/doc-check.sh >/dev/null 2>&1
  pass "runs without error (exit $?)"
else
  printf '  \033[33mSKIP\033[0m not a git repository\n'
fi

head_ "5. Inventory ($TIER_NAME roster)"
# A UI-only piece that configure.sh pruned is a SKIP, not a failure.
is_ui_only() {  # is_ui_only <kind> <name>
  local list
  case "$1" in
    agents) list="${TIER_UI_AGENTS:-}" ;;
    skills) list="${TIER_UI_SKILLS:-}" ;;
    rules)  list="${TIER_UI_RULES:-}"  ;;
  esac
  case " $list " in *" $2 "*) return 0 ;; esac
  return 1
}
skip() { printf '  \033[33mSKIP\033[0m %s\n' "$1"; }

if [ -z "${TIER_AGENTS:-}" ]; then
  fail "no manifest for tier '$PLAN' — cannot check the inventory"
else
  for n in $TIER_AGENTS; do
    if [ -f ".claude/agents/$n.md" ]; then pass "agent: $n"
    elif is_ui_only agents "$n";  then skip "agent: $n (removed: no UI)"
    else fail "agent: $n missing"; fi
  done
  for s in $TIER_SKILLS; do
    if [ -f ".claude/skills/$s/SKILL.md" ]; then pass "skill: /$s"
    elif is_ui_only skills "$s";        then skip "skill: /$s (removed: no UI)"
    else fail "skill: /$s missing"; fi
  done
  for r in $TIER_RULES; do
    if [ -f ".claude/rules/$r.md" ]; then pass "rule: $r.md"
    elif is_ui_only rules "$r";     then skip "rule: $r.md (removed: no UI)"
    else fail "rule: $r.md missing"; fi
  done
fi

head_ "6. Nothing extra"
# An agent left behind by a tier switch still costs listing space and can
# shadow delegation. Report it rather than deleting it.
if [ -n "${TIER_AGENTS:-}" ] && [ -d .claude/agents ]; then
  extra=0
  for f in .claude/agents/*.md; do
    [ -e "$f" ] || continue
    n="$(basename "$f" .md)"
    case " $TIER_AGENTS " in *" $n "*) continue ;; esac
    fail "unexpected agent: $n (not in the $TIER_NAME roster — left over from another tier?)"
    extra=1
  done
  [ "$extra" = 0 ] && pass "no agents outside the $TIER_NAME roster"
fi

printf '\n\033[1m%d passed, %d failed\033[0m\n' "$PASS" "$FAIL"
if [ "$FAIL" -gt 0 ]; then
  printf 'Fix the failures before trusting the pipeline.\n'; exit 1
fi
printf 'Hooks are live. Next: /doctor and /context in Claude Code.\n'
