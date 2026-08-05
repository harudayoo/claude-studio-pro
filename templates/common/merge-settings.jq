# Merge an existing .claude/settings.json with a studio tier template.
#
#   jq -s -f merge-settings.jq <existing> <template>
#
# Slurped input, not --argfile / --slurpfile: those spellings differ across
# jq 1.6 and 1.7, and this has to run on whatever the user has.
#
# Three rules, in order of how often they matter:
#
#   1. Permissions are unioned. Losing a deny rule on an update is a security
#      regression; losing an allow rule is a permission prompt you already
#      answered.
#   2. Studio hooks are authoritative, but FOREIGN hooks are preserved. A hook
#      whose command points outside .claude/hooks/ belongs to something else —
#      a design plugin's detector, a house lint hook — and silently dropping it
#      on every update is how people stop trusting the installer.
#   3. Everything else: the template wins, recursively.
#
# Read the two inputs as $cur and $tpl so the merged object can be built
# without re-indexing a value that has already been rewritten.

def is_studio_hook:
  # A hook entry is studio-owned when every command it runs lives in
  # .claude/hooks/. Entries with no command at all are treated as foreign.
  (.hooks // []) as $h
  | ($h | length) > 0
    and ($h | all(.command // "" | startswith(".claude/hooks/")));

def merge_hook_event($cur_event; $tpl_event):
  # Template entries first, then anything foreign the project already had.
  ($tpl_event // [])
  + (($cur_event // []) | map(select(is_studio_hook | not)));

.[0] as $cur
| .[1] as $tpl
| ($cur.hooks // {}) as $ch
| ($tpl.hooks // {}) as $th
| ($cur * $tpl)
| .permissions.deny =
    ((($cur.permissions.deny  // []) + ($tpl.permissions.deny  // [])) | unique)
| .permissions.allow =
    ((($cur.permissions.allow // []) + ($tpl.permissions.allow // [])) | unique)
| .hooks = (
    reduce (($ch | keys_unsorted) + ($th | keys_unsorted) | unique)[] as $event
      ({}; .[$event] = merge_hook_event($ch[$event]; $th[$event]))
  )
