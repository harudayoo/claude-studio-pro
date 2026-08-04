#!/usr/bin/env bash
#
# claude-studio-pro installer
#
# Installs a lean, Pro-plan-sized Claude Code pipeline into a project:
#   7 subagents, 5 skills, 4 path-scoped rules, 4 hooks, docs scaffolding.
#
# Design rules this script follows:
#   1. Never destroy. Existing files are backed up before being touched.
#   2. Never guess silently. Detected values are written as {{PLACEHOLDERS}}
#      with a NEEDS_REVIEW marker until you confirm them.
#   3. Unconfigured hooks are LOUD, not inert. A hook with unresolved
#      placeholders warns on stderr rather than passing quietly.
#   4. Idempotent. Re-running updates templates without clobbering your edits.
#
set -euo pipefail

VERSION="1.0.0"
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="$(pwd)"
DRY_RUN=0
FORCE=0
NO_DOCS=0
UNINSTALL=0
STAMP="$(date +%Y%m%d-%H%M%S)"

c_red()  { printf '\033[31m%s\033[0m\n' "$*"; }
c_grn()  { printf '\033[32m%s\033[0m\n' "$*"; }
c_yel()  { printf '\033[33m%s\033[0m\n' "$*"; }
c_dim()  { printf '\033[2m%s\033[0m\n' "$*"; }
die()    { c_red "error: $*" >&2; exit 1; }

usage() {
  cat <<'HELPTEXT'
claude-studio-pro installer

USAGE
  ./install.sh [OPTIONS]
  ./install.sh --target /path/to/project

OPTIONS
  --target DIR     Project to install into (default: current directory)
  --dry-run        Show what would happen, change nothing
  --force          Overwrite existing studio files (backup still taken)
  --no-docs        Skip the docs/ scaffolding
  --uninstall      Remove studio files (backup taken first)
  --version        Print version
  -h, --help       This message

AFTER INSTALL
  1. Edit docs/setup/PROFILE.md and run every command in it.
  2. Run: ./configure.sh --target DIR   (fills placeholders from the profile)
  3. Open Claude Code and run /doctor, then /context.
HELPTEXT
}

while [ $# -gt 0 ]; do
  case "$1" in
    --target)    TARGET="$(cd "$2" 2>/dev/null && pwd)" || die "no such directory: $2"; shift 2 ;;
    --dry-run)   DRY_RUN=1; shift ;;
    --force)     FORCE=1; shift ;;
    --no-docs)   NO_DOCS=1; shift ;;
    --uninstall) UNINSTALL=1; shift ;;
    --version)   echo "$VERSION"; exit 0 ;;
    -h|--help)   usage; exit 0 ;;
    *)           die "unknown option: $1 (try --help)" ;;
  esac
done

[ -d "$SRC/templates" ] || die "templates/ not found next to install.sh"
[ -d "$TARGET" ]        || die "target does not exist: $TARGET"

BACKUP="$TARGET/.claude/.backup-$STAMP"

run() { if [ "$DRY_RUN" = 1 ]; then c_dim "  would: $*"; else eval "$@"; fi; }

backup_if_exists() {
  local p="$1"
  [ -e "$p" ] || return 0
  local rel="${p#$TARGET/}"
  run "mkdir -p '$BACKUP/$(dirname "$rel")'"
  run "cp -a '$p' '$BACKUP/$rel'"
  c_dim "  backed up $rel"
}

# ---------------------------------------------------------------- uninstall
if [ "$UNINSTALL" = 1 ]; then
  c_yel "Uninstalling claude-studio from $TARGET"
  for p in .claude/agents .claude/skills .claude/rules .claude/hooks .claude/state; do
    backup_if_exists "$TARGET/$p"
    run "rm -rf '$TARGET/$p'"
  done
  c_grn "Removed. Backup at ${BACKUP#$TARGET/}"
  c_dim "docs/, CLAUDE.md and settings.json were left alone — remove by hand if you want them gone."
  exit 0
fi

# --------------------------------------------------------------- detection
detect_stack() {
  STACK="unknown"; PKG=""; HAS_UI="unknown"
  DEV_CMD="NEEDS_REVIEW"; TEST_CMD="NEEDS_REVIEW"; SINGLE_TEST_CMD="NEEDS_REVIEW"
  FORMAT_CMD="NEEDS_REVIEW"; TYPECHECK_CMD="NEEDS_REVIEW"; BUILD_CMD="NEEDS_REVIEW"
  SOURCE_ROOTS="NEEDS_REVIEW"; FRONTEND_ROOT="NEEDS_REVIEW"; TEST_ROOT="NEEDS_REVIEW"
  TOKEN_FILE="NEEDS_REVIEW"; AUDIT_CMD="NEEDS_REVIEW"

  if [ -f "$TARGET/composer.json" ]; then
    STACK="PHP"; PKG="composer"
    grep -q '"laravel/framework"' "$TARGET/composer.json" 2>/dev/null && STACK="Laravel"
    TEST_CMD="php artisan test"; SINGLE_TEST_CMD="php artisan test --filter"
    DEV_CMD="php artisan serve"
    [ -f "$TARGET/vendor/bin/pint" ] && FORMAT_CMD="./vendor/bin/pint"
    [ -f "$TARGET/vendor/bin/phpstan" ] && TYPECHECK_CMD="./vendor/bin/phpstan analyse"
    SOURCE_ROOTS="app"; TEST_ROOT="tests"
    AUDIT_CMD="composer audit"
  fi

  if [ -f "$TARGET/package.json" ]; then
    [ "$STACK" = "unknown" ] && STACK="JavaScript/TypeScript" || STACK="$STACK + Node"
    if   [ -f "$TARGET/pnpm-lock.yaml" ]; then PKG="pnpm"
    elif [ -f "$TARGET/yarn.lock" ];      then PKG="yarn"
    elif [ -f "$TARGET/bun.lockb" ];      then PKG="bun"
    else PKG="npm"; fi
    # Read a script from package.json. Uses jq when present, falls back to sed.
    pkg_script() {
      if command -v jq >/dev/null 2>&1; then
        jq -r ".scripts.\"$1\" // empty" "$TARGET/package.json" 2>/dev/null
      else
        tr -d '\n' < "$TARGET/package.json" \
          | grep -o "\"$1\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" \
          | head -1 | sed 's/.*:[[:space:]]*"//; s/"$//'
      fi
    }
    if true; then
      for s in dev test build lint typecheck; do
        v=$(pkg_script "$s" || true)
        [ -n "$v" ] || continue
        case "$s" in
          dev)       DEV_CMD="$PKG run dev" ;;
          build)     BUILD_CMD="$PKG run build" ;;
          lint)      [ "$FORMAT_CMD" = "NEEDS_REVIEW" ] && FORMAT_CMD="$PKG run lint" ;;
          typecheck) TYPECHECK_CMD="$PKG run typecheck" ;;
          test)
            # A watching test script would hang the filter hook.
            case "$v" in
              *--watch*|*watch*|*jest\ --watch*|vitest)
                TEST_CMD="NEEDS_REVIEW  # '$PKG run test' looks like a WATCHER" ;;
              *) TEST_CMD="$PKG run test" ;;
            esac ;;
        esac
      done
    fi
    [ -f "$TARGET/tsconfig.json" ] && [ "$TYPECHECK_CMD" = "NEEDS_REVIEW" ] \
      && TYPECHECK_CMD="npx tsc --noEmit"
    for d in src app resources/js frontend; do
      [ -d "$TARGET/$d" ] && { FRONTEND_ROOT="$d"; break; }
    done
    [ "$SOURCE_ROOTS" = "NEEDS_REVIEW" ] && [ "$FRONTEND_ROOT" != "NEEDS_REVIEW" ] \
      && SOURCE_ROOTS="$FRONTEND_ROOT"
    for d in tests test __tests__ spec; do
      [ -d "$TARGET/$d" ] && { TEST_ROOT="$d"; break; }
    done
    HAS_UI="probably yes"
    node_audit_cmd="$PKG audit"; [ "$PKG" = "yarn" ] && node_audit_cmd="yarn audit"
    if [ "$AUDIT_CMD" = "NEEDS_REVIEW" ]; then
      AUDIT_CMD="$node_audit_cmd"
    else
      AUDIT_CMD="$AUDIT_CMD && $node_audit_cmd"
    fi
  fi

  if [ -f "$TARGET/pyproject.toml" ] || [ -f "$TARGET/requirements.txt" ]; then
    [ "$STACK" = "unknown" ] && STACK="Python"
    PKG="${PKG:-pip}"; TEST_CMD="pytest"; SINGLE_TEST_CMD="pytest -k"
    [ -d "$TARGET/src" ] && SOURCE_ROOTS="src"
    TEST_ROOT="tests"
    [ "$AUDIT_CMD" = "NEEDS_REVIEW" ] && AUDIT_CMD="pip-audit"
  fi

  [ -f "$TARGET/go.mod" ]    && { STACK="Go";   TEST_CMD="go test ./..."; BUILD_CMD="go build ./..."
                                   [ "$AUDIT_CMD" = "NEEDS_REVIEW" ] && AUDIT_CMD="govulncheck ./..."; }
  [ -f "$TARGET/Cargo.toml" ] && { STACK="Rust"; TEST_CMD="cargo test";   BUILD_CMD="cargo build"
                                   [ "$AUDIT_CMD" = "NEEDS_REVIEW" ] && AUDIT_CMD="cargo audit"; }

  TOKEN_FILE="NEEDS_REVIEW"
  for f in src/styles/tokens.css src/tokens.css resources/css/tokens.css \
           app/globals.css src/app/globals.css styles/tokens.css; do
    [ -f "$TARGET/$f" ] && { TOKEN_FILE="$f"; break; }
  done

  PROJECT_NAME="$(basename "$TARGET")"
  if [ -f "$TARGET/package.json" ]; then
    if command -v jq >/dev/null 2>&1; then
      n=$(jq -r '.name // empty' "$TARGET/package.json" 2>/dev/null || true)
    else
      n=$(tr -d '\n' < "$TARGET/package.json" \
          | grep -o '"name"[[:space:]]*:[[:space:]]*"[^"]*"' \
          | head -1 | sed 's/.*:[[:space:]]*"//; s/"$//')
    fi
    [ -n "${n:-}" ] && PROJECT_NAME="$n"
  fi
}

# ------------------------------------------------------------------- start
echo
c_grn "claude-studio-pro v$VERSION"
c_dim "source: $SRC"
c_dim "target: $TARGET"
[ "$DRY_RUN" = 1 ] && c_yel "DRY RUN — nothing will be written"
echo

command -v jq  >/dev/null 2>&1 || c_yel "warning: jq not found. The gate hook requires it. Install jq before using the pipeline."
command -v git >/dev/null 2>&1 || c_yel "warning: git not found. The doc-check hook will no-op."
[ -d "$TARGET/.git" ] || c_yel "warning: target is not a git repository. Studio expects version control."

detect_stack
c_grn "Detected: $STACK  (package manager: ${PKG:-n/a})"
echo

if [ -d "$TARGET/.claude/agents" ] && [ "$FORCE" = 0 ]; then
  c_yel "An existing .claude/agents/ was found."
  c_dim "Re-running will back it up and replace studio-owned files."
  printf "Continue? [y/N] "
  read -r ans; case "$ans" in y|Y) ;; *) die "aborted" ;; esac
  echo
fi

# --------------------------------------------------------------- directories
c_grn "1. Creating directories"
for d in .claude/agents .claude/skills .claude/rules .claude/hooks \
         .claude/state .claude/agent-memory; do
  run "mkdir -p '$TARGET/$d'"
done
if [ "$NO_DOCS" = 0 ]; then
  for d in docs/setup docs/adr docs/specs docs/handoff docs/reports; do
    run "mkdir -p '$TARGET/$d'"
  done
fi

# ------------------------------------------------------------------- copy
c_grn "2. Installing agents, skills, rules, hooks"
for f in "$SRC"/templates/agents/*.md; do
  d="$TARGET/.claude/agents/$(basename "$f")"; backup_if_exists "$d"; run "cp '$f' '$d'"
done
run "cp -R '$SRC/templates/skills/.' '$TARGET/.claude/skills/'"
for f in "$SRC"/templates/rules/*.md; do
  d="$TARGET/.claude/rules/$(basename "$f")"; backup_if_exists "$d"; run "cp '$f' '$d'"
done
run "cp '$SRC/templates/hooks/'*.sh '$TARGET/.claude/hooks/'"
run "chmod +x '$TARGET/.claude/hooks/'*.sh"
[ -f "$TARGET/.claude/state/gate.json" ] || run "cp '$SRC/templates/state/gate.json' '$TARGET/.claude/state/gate.json'"

if [ "$NO_DOCS" = 0 ]; then
  [ -f "$TARGET/docs/adr/TEMPLATE.md" ] || run "cp '$SRC/templates/docs/adr/TEMPLATE.md' '$TARGET/docs/adr/TEMPLATE.md'"
fi

# ------------------------------------------------------------------ render
# Escape a value for safe use as a sed *replacement* string: backslash first
# (so later steps don't double-escape what they introduce), then & (whole-
# match in sed replacement syntax), then | (our delimiter). Without this, a
# value containing either — e.g. a combined "composer audit && npm audit" —
# corrupts every other placeholder in the same sed invocation.
esc_repl() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/&/\\\&/g' -e 's/|/\\|/g'; }

render() {  # render <template> <destination>
  local tpl="$1" dst="$2"
  if [ "$DRY_RUN" = 1 ]; then c_dim "  would render $(basename "$tpl") -> ${dst#$TARGET/}"; return; fi
  sed \
    -e "s|{{PROJECT_NAME}}|$(esc_repl "$PROJECT_NAME")|g" \
    -e "s|{{STACK_LINE}}|$(esc_repl "$STACK")|g" \
    -e "s|{{PACKAGE_MANAGER}}|$(esc_repl "${PKG:-n/a}")|g" \
    -e "s|{{DEV_COMMAND}}|$(esc_repl "$DEV_CMD")|g" \
    -e "s|{{TEST_COMMAND}}|$(esc_repl "$TEST_CMD")|g" \
    -e "s|{{SINGLE_TEST_COMMAND}}|$(esc_repl "$SINGLE_TEST_CMD")|g" \
    -e "s|{{FORMAT_COMMAND}}|$(esc_repl "$FORMAT_CMD")|g" \
    -e "s|{{TYPECHECK_COMMAND}}|$(esc_repl "$TYPECHECK_CMD")|g" \
    -e "s|{{BUILD_COMMAND}}|$(esc_repl "$BUILD_CMD")|g" \
    -e "s|{{DEPENDENCY_AUDIT_COMMAND}}|$(esc_repl "$AUDIT_CMD")|g" \
    -e "s|{{SOURCE_ROOTS}}|$(esc_repl "$SOURCE_ROOTS")|g" \
    -e "s|{{FRONTEND_ROOT}}|$(esc_repl "$FRONTEND_ROOT")|g" \
    -e "s|{{TEST_ROOT}}|$(esc_repl "$TEST_ROOT")|g" \
    -e "s|{{TOKEN_FILE}}|$(esc_repl "$TOKEN_FILE")|g" \
    -e "s|{{HAS_UI}}|$(esc_repl "$HAS_UI")|g" \
    "$tpl" > "$dst"
}

c_grn "3. Rendering profile"
if [ "$NO_DOCS" = 0 ]; then
  if [ -f "$TARGET/docs/setup/PROFILE.md" ] && [ "$FORCE" = 0 ]; then
    c_dim "  docs/setup/PROFILE.md exists — left alone"
  else
    backup_if_exists "$TARGET/docs/setup/PROFILE.md"
    render "$SRC/templates/docs/setup/PROFILE.md.tmpl" "$TARGET/docs/setup/PROFILE.md"
  fi
fi

c_grn "4. CLAUDE.md"
if [ -f "$TARGET/CLAUDE.md" ]; then
  c_yel "  CLAUDE.md already exists — NOT overwritten."
  c_dim "  A studio version was written to CLAUDE.studio.md. Merge by hand."
  render "$SRC/templates/CLAUDE.md.tmpl" "$TARGET/CLAUDE.studio.md"
else
  render "$SRC/templates/CLAUDE.md.tmpl" "$TARGET/CLAUDE.md"
fi

c_grn "5. settings.json"
S="$TARGET/.claude/settings.json"
if [ ! -f "$S" ]; then
  run "cp '$SRC/templates/settings.json.tmpl' '$S'"
elif command -v jq >/dev/null 2>&1; then
  backup_if_exists "$S"
  if [ "$DRY_RUN" = 0 ]; then
    jq -s '.[0] * .[1]
           | .permissions.deny  = ((.[0].permissions.deny  // []) + (.[1].permissions.deny  // []) | unique)
           | .permissions.allow = ((.[0].permissions.allow // []) + (.[1].permissions.allow // []) | unique)' \
       "$S" "$SRC/templates/settings.json.tmpl" > "$S.new" 2>/dev/null \
      && mv "$S.new" "$S" \
      || { rm -f "$S.new"; cp "$SRC/templates/settings.json.tmpl" "$TARGET/.claude/settings.studio.json"
           c_yel "  merge failed — wrote .claude/settings.studio.json instead. Merge by hand."; }
    c_dim "  merged (hooks from the template win; permissions are unioned)"
  fi
else
  run "cp '$SRC/templates/settings.json.tmpl' '$TARGET/.claude/settings.studio.json'"
  c_yel "  jq missing — wrote .claude/settings.studio.json. Merge by hand."
fi

c_grn "6. .gitignore"
if [ "$DRY_RUN" = 0 ]; then
  for line in "CLAUDE.local.md" ".claude/settings.local.json" ".claude/.backup-*" ".claude/agent-memory-local/"; do
    grep -qxF "$line" "$TARGET/.gitignore" 2>/dev/null || echo "$line" >> "$TARGET/.gitignore"
  done
fi

# ------------------------------------------------------------------ report
echo
c_grn "Installed."
[ -d "$BACKUP" ] && c_dim "Backup: ${BACKUP#$TARGET/}"
echo
c_yel "UNRESOLVED PLACEHOLDERS — the pipeline is inert until these are filled:"
if [ "$DRY_RUN" = 0 ]; then
  grep -rl '{{[A-Z_]*}}' "$TARGET/.claude" 2>/dev/null | sed "s|$TARGET/|  |" || echo "  none"
fi
echo
cat <<NEXT
NEXT STEPS

  1. Open docs/setup/PROFILE.md. Fill every NEEDS_REVIEW field.
     Run each command yourself. A field is not confirmed until its
     command has executed. Watch for a watching test script -- that
     will hang the output filter.

  2. Fill the placeholders:
        ./configure.sh --target "$TARGET"

  3. In Claude Code:
        /doctor      # duplicate agents, oversized memory
        /context     # pre-prompt total should be under ~12%
        /hooks       # confirm all four registered

  4. Test each hook deliberately (see README, "Verifying the install").

  5. Seed agent memory (three read-only passes -- see README).

  6. Run one real pilot feature end to end, then record /usage
     into docs/reports/baseline.md.

NEXT
