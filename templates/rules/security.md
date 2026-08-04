---
paths:
  - "{{BACKEND_GLOB}}"
  - "{{FRONTEND_GLOB}}"
---

# Security standards

**Authorisation.** Checked at every entry point, not only in the UI. A new
route, job, command, or webhook without an explicit authorisation check is a
blocker.

**Authorisation source of truth.** If there is more than one way to arrive at
"what can this actor do" — a stored role plus a session/admin override, a
cached permission plus a live one — every check must go through the single
resolved value. A check that reads the raw underlying field instead of the
resolver is a blocker even if it happens to be correct today, because the
override path silently stops applying to it.

**Cross-tenant / cross-owner scope.** Any query reachable with a
client-supplied ID that crosses a tenant, organisation, team, or owner
boundary must filter server-side by the requester's resolved scope. A button
being hidden in the UI is not the control — trace the query and confirm the
scope filter is actually applied, not merely present somewhere else in the
same file.

**Input.** Validated and typed at the boundary. Allowlist over denylist.
Never build a query, path, command, or URL from unvalidated input.

**Secrets.** From environment only. Never in source, fixtures, logs, error
messages, or client bundles. Never read or write `.env` from application code.

**Output.** Encoded for its destination — HTML, SQL, shell, URL. Rely on the
framework's escaping; do not disable it for convenience.

**Dependencies.** A new dependency needs a stated reason, a maintenance
check, and a licence check. Prefer the standard library.

**Data.** Classify anything personal. Minimise what is stored. State the
retention period. Redact in logs and in error reporting.
