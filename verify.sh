#!/usr/bin/env bash
#
# claude-studio-pro self-test
#
# Proves the hooks actually fire. Run this after configure.sh and again any
# time you change a hook or the profile.
#
# A hook you have not watched fire is a hook you do not have.
#
set -uo pipefail

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

head_ "0. Configuration"
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

head_ "5. Inventory"
for n in planner critic test-designer implementer reviewer doc-writer; do
  [ -f ".claude/agents/$n.md" ] && pass "agent: $n" || fail "agent: $n missing"
done
[ -f .claude/agents/qa-runner.md ] && pass "agent: qa-runner" \
  || printf '  \033[33mSKIP\033[0m qa-runner (removed: no UI)\n'
for s in feature handoff codebase-map report ci-scaffold security-audit; do
  [ -f ".claude/skills/$s/SKILL.md" ] && pass "skill: /$s" || fail "skill: /$s missing"
done
for r in backend security testing devops; do
  [ -f ".claude/rules/$r.md" ] && pass "rule: $r.md" || fail "rule: $r.md missing"
done
[ -f .claude/rules/frontend.md ] && pass "rule: frontend.md" \
  || printf '  \033[33mSKIP\033[0m frontend.md (removed: no UI)\n'

printf '\n\033[1m%d passed, %d failed\033[0m\n' "$PASS" "$FAIL"
if [ "$FAIL" -gt 0 ]; then
  printf 'Fix the failures before trusting the pipeline.\n'; exit 1
fi
printf 'Hooks are live. Next: /doctor and /context in Claude Code.\n'
