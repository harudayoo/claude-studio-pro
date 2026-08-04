#!/usr/bin/env bash
# Shared helpers for studio hooks.
#
# Two jobs:
#   1. An UNCONFIGURED hook must be LOUD, never silently inert.
#   2. Read JSON without hard-depending on jq. jq is used when present
#      because it is correct; the fallback keeps hooks working without it.

studio_guard() {
  local self="$1"
  if grep -q '{{[A-Z_]*}}' "$self" 2>/dev/null; then
    echo "claude-studio: $(basename "$self") has unresolved placeholders." >&2
    echo "  Fill docs/setup/PROFILE.md, then run ./configure.sh" >&2
    return 1
  fi
  return 0
}

# json_field <json> <dotted.path>
# Handles the shallow paths studio hooks need, e.g. tool_input.file_path
json_field() {
  local json="$1" path="$2"
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$json" | jq -r ".${path} // empty" 2>/dev/null
    return
  fi
  # Fallback: last key of the path, first match, unescaped minimally.
  local key="${path##*.}"
  printf '%s' "$json" \
    | tr -d '\n' \
    | grep -o "\"$key\"[[:space:]]*:[[:space:]]*\"\(\\\\.\|[^\"\\\\]\)*\"" \
    | head -1 \
    | sed 's/^"[^"]*"[[:space:]]*:[[:space:]]*"//; s/"$//; s/\\"/"/g; s/\\\\/\\/g'
}

# json_escape <string>  -> a JSON string body (no surrounding quotes)
json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}
